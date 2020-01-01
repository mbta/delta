defmodule Delta.Producer do
  @moduledoc """
  GenStage which fulfills demand by making HTTP requests on a configurable frequency.
  """
  @type opts :: [opt]
  @type opt :: {:url, binary} | {:frequency, non_neg_integer} | {:http_mod, module}

  @default_frequency 60_000
  @default_http_mod Delta.Producer.Hackney

  use GenStage
  require Logger

  @start_link_opts [:name]

  def start_link(opts) do
    _ = Keyword.fetch!(opts, :url)
    GenStage.start_link(__MODULE__, opts, Keyword.take(opts, @start_link_opts))
  end

  defstruct [:conn, :http_mod, :frequency, :last_fetched, :ref, headers: [], demand: 0]

  @impl GenStage
  def init(opts) do
    url = Keyword.get(opts, :url)
    frequency = Keyword.get(opts, :frequency, @default_frequency)
    http_mod = Keyword.get(opts, :http_mod, @default_http_mod)
    {:ok, conn} = http_mod.new(url)

    state = %__MODULE__{
      conn: conn,
      http_mod: http_mod,
      frequency: frequency,
      last_fetched: monotonic_now() - frequency - 1
    }

    {:producer, state}
  end

  @impl GenStage
  def handle_demand(demand, state) do
    state = %{state | demand: state.demand + demand}
    state = schedule_fetch(state)
    {:noreply, [], state}
  end

  @impl GenStage
  def handle_info(:fetch, %{demand: demand} = state) when demand > 0 do
    state = %{state | ref: nil, last_fetched: monotonic_now()}
    state = schedule_fetch(state)

    case state.http_mod.fetch(state.conn) do
      {:ok, conn, file} ->
        state = %{state | conn: conn}
        handle_file(state, file)

      {:unmodified, conn} ->
        state = %{state | conn: conn}
        {:noreply, [], state}

      {:error, conn, reason} ->
        state = %{state | conn: conn}
        handle_error(state, reason)
    end
  end

  def handle_info(:fetch, %{demand: 0} = state) do
    # wait for more demand before scheduling again
    {:noreply, [], state}
  end

  defp handle_file(state, file) do
    state = %{state | demand: max(state.demand - 1, 0)}
    {:noreply, [file], state}
  end

  def handle_error(state, reason) do
    _ =
      Logger.warn(fn ->
        "#{__MODULE__} error fetching url=#{inspect(state.conn.url)} error=#{inspect(reason)}"
      end)

    {:noreply, [], state}
  end

  defp schedule_fetch(%{ref: nil} = state) do
    next_fetch_after = max(state.last_fetched + state.frequency - monotonic_now(), 0)
    ref = Process.send_after(self(), :fetch, next_fetch_after)
    %{state | ref: ref}
  end

  defp monotonic_now do
    System.monotonic_time(:millisecond)
  end
end

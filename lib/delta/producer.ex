defmodule Delta.Producer do
  @moduledoc """
  GenStage which fulfills demand by making HTTP requests on a configurable frequency.
  """
  alias Delta.File
  use GenStage
  require Logger

  @type opts :: [opt]
  @type opt ::
          {:url, binary}
          | {:frequency, non_neg_integer}
          | {:http_mod, module}
          | {:filters, [filter]}
  @type filter :: (File.t() -> File.t())

  @default_frequency 60_000
  @default_http_mod Delta.Producer.Hackney

  @start_link_opts [:name]

  def start_link(opts) do
    _ = Keyword.fetch!(opts, :url)
    GenStage.start_link(__MODULE__, opts, Keyword.take(opts, @start_link_opts))
  end

  defstruct [:conn, :http_mod, :frequency, :filters, :last_fetched, :ref, headers: [], demand: 0]

  @impl GenStage
  def init(opts) do
    url = Keyword.get(opts, :url)
    frequency = Keyword.get(opts, :frequency, @default_frequency)
    http_mod = Keyword.get(opts, :http_mod, @default_http_mod)
    filters = Keyword.get(opts, :filters, [&File.ensure_content_type/1, &File.ensure_gzipped/1])
    {:ok, conn} = http_mod.new(url)

    state = %__MODULE__{
      conn: conn,
      http_mod: http_mod,
      filters: filters,
      frequency: frequency,
      last_fetched: monotonic_now() - frequency - 1
    }

    {:producer, state, dispatcher: GenStage.BroadcastDispatcher}
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

  def handle_info(message, state) do
    case state.http_mod.stream(state.conn, message) do
      {:ok, conn, files} ->
        state = %{state | conn: conn}
        {:noreply, files, state}

      :unknown ->
        _ =
          Logger.warn(
            "#{__MODULE__} unexpected message message=#{inspect(message)} state=#{inspect(state)}"
          )

        {:noreply, [], state}
    end
  end

  defp handle_file(state, file) do
    file = apply_filters(file, state.filters)
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

  # coveralls-ignore-start
  defp schedule_fetch(%{ref: _} = state) do
    # already scheduled!  this isn't always hit during testing (but it is
    # sometimes) so we skip the coverage check.
    state
  end

  # coveralls-ignore-stop

  defp monotonic_now do
    System.monotonic_time(:millisecond)
  end

  @spec apply_filters(File.t(), [filter]) :: File.t()
  defp apply_filters(%File{} = file, [filter | rest]) do
    %File{} = file = filter.(file)
    apply_filters(file, rest)
  end

  defp apply_filters(%File{} = file, []) do
    file
  end
end

defmodule Delta.Producer.S3Producer do
  @moduledoc """
  GenStage which produces files by polling s3
  """

  alias Delta.File
  alias Delta.Producer.Filter
  use GenStage
  require Logger

  @type opts :: [opt]
  @type opt ::
          {:bucket, binary}
          | {:path, binary}
          | {:frequency, non_neg_integer}
          | {:filters, [Delta.Producer.filter()]}
          | {:ex_aws, module}

  @start_link_opts [:name]

  @default_frequency 60_000

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts, Keyword.take(opts, @start_link_opts))
  end

  @type state :: %__MODULE__{
          ex_aws: module(),
          bucket: String.t(),
          path: String.t(),
          frequency: non_neg_integer(),
          filters: [Filter.t()],
          next_fetch_ref: reference() | nil,
          etag: String.t() | nil,
          last_modified: String.t() | nil,
          demand: non_neg_integer()
        }
  defstruct [
    :ex_aws,
    :bucket,
    :path,
    :frequency,
    :filters,
    :last_fetched,
    :next_fetch_ref,
    :etag,
    :last_modified,
    demand: 0
  ]

  @impl GenStage
  def init(opts) do
    frequency = Keyword.get(opts, :frequency, @default_frequency)

    state = %__MODULE__{
      ex_aws: Keyword.get(opts, :ex_aws, ExAws),
      bucket: Keyword.get(opts, :bucket),
      path: Keyword.get(opts, :path),
      filters: Keyword.get(opts, :filters, Filter.default_filters()),
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
    state = %{state | next_fetch_ref: nil, last_fetched: monotonic_now()}
    state = schedule_fetch(state)

    case state.ex_aws.request(
           ExAws.S3.get_object(state.bucket, state.path,
             if_none_match: state.etag,
             if_modified_since: state.last_modified
           )
         ) do
      {:ok, %{status_code: 200, body: body, headers: headers}} ->
        file = %File{
          updated_at: get_updated_at(headers),
          url: s3_url(state.bucket, state.path),
          body: body,
          content_type: find_header(headers, "content-type"),
          encoding: :none
        }

        files = Filter.apply_filters([file], state.filters)

        state = %{
          state
          | etag: find_header(headers, "etag"),
            last_modified: find_header(headers, "last-modified"),
            demand: max(state.demand - Enum.count(files), 0)
        }

        {:noreply, files, state}

      # not modified
      {:ok, %{status_code: 304}} ->
        {:noreply, [], state}

      {_, error} ->
        Logger.warn(fn ->
          "#{__MODULE__} error fetching s3 url=#{s3_url(state.bucket, state.path)}} error=#{
            inspect(error, limit: :infinity)
          }"
        end)

        {:noreply, [], state}
    end
  end

  def handle_info(:fetch, %{demand: 0} = state) do
    # wait for more demand before scheduling again
    {:noreply, [], state}
  end

  defp schedule_fetch(%{next_fetch_ref: nil} = state) do
    next_fetch_after = max(state.last_fetched + state.frequency - monotonic_now(), 0)
    next_fetch_ref = Process.send_after(self(), :fetch, next_fetch_after)
    %{state | next_fetch_ref: next_fetch_ref}
  end

  # coveralls-ignore-start
  defp schedule_fetch(%{next_fetch_ref: _} = state) do
    # already scheduled!  this isn't always hit during testing (but it is
    # sometimes) so we skip the coverage check.
    state
  end

  # coveralls-ignore-stop

  defp monotonic_now do
    System.monotonic_time(:millisecond)
  end

  @spec s3_url(String.t(), String.t()) :: String.t()
  defp s3_url(bucket, path) do
    "s3://#{bucket}/#{path}"
  end

  @spec find_header([{String.t(), String.t()}], String.t()) :: String.t() | nil
  defp find_header(headers, header) do
    Enum.find_value(headers, fn {key, value} ->
      String.downcase(key) == header and value
    end)
  end

  @spec get_updated_at([{binary(), binary()}]) :: DateTime.t()
  defp get_updated_at(headers) do
    case find_header(headers, "last-modified") do
      nil ->
        DateTime.now("Etc/UTC")

      bin ->
        erl_dt = :cow_date.parse_date(bin)
        naive_dt = NaiveDateTime.from_erl!(erl_dt)
        DateTime.from_naive!(naive_dt, "Etc/UTC")
    end
  end
end

defmodule Delta.Producer.S3ProducerTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias __MODULE__.FakeAws
  alias Delta.File
  alias Delta.Producer.S3Producer

  setup do
    {:ok, _pid} = FakeAws.start_link()
    :ok
  end

  test "sends files to consumers" do
    FakeAws.mock_responses([{200, "body1"}, {200, "body2"}])

    {time_usec, result} =
      :timer.tc(fn ->
        take_files(2)
      end)

    # waited at least 500ms between fetches
    assert time_usec >= 500_000
    assert [file1, file2] = result

    assert %File{
             updated_at: _,
             url: "s3://bucket/path/path",
             body: body1,
             content_type: "application/octet-stream",
             encoding: :gzip
           } = file1

    assert body1 == :zlib.gzip("body1")
    assert %File{body: body2} = file2
    assert body2 == :zlib.gzip("body2")
  end

  test "does not fetch more than demanded" do
    FakeAws.mock_responses([{200, "demanded"}, {200, "this should not be fetched"}])
    assert [%Delta.File{}] = take_files(1)
    left_over_responses = Agent.get(FakeAws, & &1)
    assert left_over_responses == [{200, "this should not be fetched"}]
  end

  @tag :capture_log
  test "refetches and logs a warning if the s3 request fails" do
    FakeAws.mock_responses([{500, ""}, {200, "body"}])

    log =
      capture_log([level: :warn], fn ->
        assert [%File{body: body}] = take_files(1)
        assert body == :zlib.gzip("body")
      end)

    assert log =~ "error fetching s3"
  end

  test "refetches after a cache response" do
    FakeAws.mock_responses([{200, "1"}, {304, ""}, {200, "2"}])

    assert [%File{body: body1}, %File{body: body2}] = take_files(2)
    assert body1 == :zlib.gzip("1")
    assert body2 == :zlib.gzip("2")
  end

  test "handles content-type" do
    FakeAws.mock_responses([
      {200, "no content type"},
      {200, "content type", [{"content-type", "application/json"}]}
    ])

    assert [
             %File{content_type: "application/octet-stream"},
             %File{content_type: "application/json"}
           ] = take_files(2)
  end

  @spec take_files(integer()) :: [File.t()]
  defp take_files(count) do
    {:ok, pid} =
      S3Producer.start_link(
        bucket: "bucket",
        path: "path/path",
        frequency: 500,
        ex_aws: FakeAws
      )

    [{pid, max_demand: count}]
    |> GenStage.stream()
    |> Enum.take(count)
  end

  defmodule FakeAws do
    @moduledoc """
    Implementation of ex_aws that allows mocking responses to get_object
    """

    @typedoc """
    {status, body, headers \\ []}
    """
    @type response :: {integer(), binary(), [{binary(), binary()}]} | {integer(), binary()}

    def start_link do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    @spec mock_responses([response()]) :: :ok
    def mock_responses(responses) do
      Agent.update(__MODULE__, fn _ -> responses end)
    end

    def request(
          %ExAws.Operation.S3{
            http_method: :get
          } = _operation
        ) do
      {status, body, headers} =
        Agent.get_and_update(__MODULE__, fn
          [{status, body, headers} | rest] -> {{status, body, headers}, rest}
          [{status, body} | rest] -> {{status, body, []}, rest}
          [] -> {{304, "", []}, []}
        end)

      {:ok,
       %{
         status_code: status,
         headers: headers,
         body: body
       }}
    end
  end
end

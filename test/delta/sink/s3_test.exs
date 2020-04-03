defmodule Delta.Sink.S3Test do
  @moduledoc false
  use ExUnit.Case
  alias __MODULE__.FakeAws
  alias Delta.File
  alias Delta.Sink.S3
  import ExUnit.CaptureLog

  @config %{
    ex_aws: FakeAws,
    bucket: "fake",
    prefix: "prefix",
    acl: "acl"
  }

  @sample_file %File{
    updated_at: ~U[2020-01-02T03:04:05Z],
    url: "https://cdn.mbta.com/realtime/Alerts.pb",
    content_type: "application/x-protobuf",
    body: "body",
    encoding: :none
  }

  setup do
    {:ok, _pid} = FakeAws.start_link()
    :ok
  end

  describe "start_link/1" do
    test "returns a pid" do
      assert {:ok, pid} = S3.start_link(Map.to_list(@config), @sample_file)
      assert is_pid(pid)
    end
  end

  describe "upload_to_s3/2" do
    @tag :capture_log
    test "creates an AWS request" do
      :ok = S3.upload_to_s3(@config, @sample_file)
      request = FakeAws.get()
      assert %ExAws.Operation.S3{} = request
      assert request.body == "body"
      assert request.bucket == "fake"

      assert %{
               "content-encoding" => "identity",
               "content-type" => "application/x-protobuf",
               "x-amz-acl" => "acl"
             } = request.headers

      assert request.path ==
               "prefix/2020/01/02/2020-01-02T03:04:05Z_https_cdn.mbta.com_realtime_Alerts.pb"
    end

    @tag :capture_log
    test "can handle gzip-encoded files" do
      :ok = S3.upload_to_s3(@config, %{@sample_file | encoding: :gzip})
      request = FakeAws.get()
      assert %{"content-encoding" => "gzip"} = request.headers
      assert request.path =~ "Alerts.pb.gz"
    end

    @tag :capture_log
    test "can handle files without a content-type" do
      :ok = S3.upload_to_s3(@config, %{@sample_file | content_type: nil})
      request = FakeAws.get()
      assert %{"content-type" => "application/octet-stream"} = request.headers
    end

    test "logs the metadata for the uploaded file" do
      log =
        capture_log([level: :info], fn ->
          S3.upload_to_s3(@config, @sample_file)
        end)

      assert log =~ "uploaded"
      assert log =~ "bucket=fake"
      assert log =~ "path=prefix/2020/"
      # length of "body"
      assert log =~ "bytes=4"
    end

    test "logs a warning if the S3 upload fails" do
      config = %{@config | ex_aws: __MODULE__.FakeAwsFailure}

      log =
        capture_log([level: :warn], fn ->
          S3.upload_to_s3(config, @sample_file)
        end)

      assert log =~ "failed to upload"
      assert log =~ "bucket=fake"
      assert log =~ "path=prefix/2020/"
      # length of "body"
      assert log =~ "bytes=4"
      assert log =~ "reason=:failure"
      assert log =~ "request=%ExAws.Operation.S3{"
    end

    test "does not upload the file if the same file already exists" do
      config = %{@config | prefix: "not_modified"}

      log =
        capture_log(fn ->
          S3.upload_to_s3(config, @sample_file)
        end)

      refute FakeAws.get()
      assert log == ""
    end

    test "re-uploads the file if the metadata is different" do
      config = %{@config | prefix: "modified"}

      log =
        capture_log(fn ->
          S3.upload_to_s3(config, @sample_file)
        end)

      assert FakeAws.get()
      refute log == ""
    end
  end

  defmodule FakeAws do
    @moduledoc "Fake AWS implementation where we can get the request."
    def start_link do
      Agent.start_link(fn -> nil end, name: __MODULE__)
    end

    def request(%{http_method: :put} = request) do
      Agent.update(__MODULE__, fn _ -> request end)
      {:ok, %{"body" => "response"}}
    end

    def request(%{http_method: :head, path: "modified" <> _}) do
      {:ok,
       %{
         status_code: 200,
         headers: [{"Content-Length", "0"}]
       }}
    end

    def request(%{http_method: :head, path: "not_modified" <> _}) do
      {:ok,
       %{
         status_code: 200,
         headers: [
           {"x-amz-id-2", "12345"},
           {"Content-Type", "application/x-protobuf"},
           {"Content-Encoding", "identity"},
           {"Content-Length", "4"}
         ]
       }}
    end

    def request(%{http_method: :head}) do
      {:error, {:http_error, 404, %{status_code: 404}}}
    end

    def get do
      Agent.get(__MODULE__, & &1)
    end
  end

  defmodule FakeAwsFailure do
    @moduledoc "Fake AWS implementation which always fails"
    def request(_request) do
      {:error, :failure}
    end
  end
end

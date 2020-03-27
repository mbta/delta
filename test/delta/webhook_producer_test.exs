defmodule Delta.WebhookProducerTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias Delta.WebhookProducer

  @authorization "Bearer token"

  setup do
    {:ok, pid} = WebhookProducer.start_link(authorization: @authorization)
    stream = GenStage.stream([{pid, cancel: :temporary}])
    {:ok, %{pid: pid, stream: stream}}
  end

  describe "send_conn/2" do
    test "creates a %File{} based on the conn", %{pid: pid, stream: stream} do
      conn = conn(:post, "/foo", "body")
      conn = put_req_header(conn, "authorization", @authorization)
      conn = put_req_header(conn, "content-type", "text/plain")

      assert :ok = WebhookProducer.send_conn(pid, conn)
      assert [%Delta.File{} = file] = Enum.take(stream, 1)
      assert file.url == "http://www.example.com/foo"
      assert file.content_type == "text/plain"
      assert file.encoding == :gzip
      assert file.body == :zlib.gzip("body")
    end

    test "can handle very large bodies", %{pid: pid, stream: stream} do
      body = String.duplicate("x", 16_000_000)
      conn = conn(:post, "/foo", body)
      conn = put_req_header(conn, "authorization", @authorization)

      assert :ok = WebhookProducer.send_conn(pid, conn)
      assert [%Delta.File{} = file] = Enum.take(stream, 1)
      assert file.body == :zlib.gzip(body)
    end

    test "ignores responses which are not authorized", %{pid: pid} do
      conn = conn(:post, "/foo", "")

      task =
        Task.async(fn ->
          [{pid, cancel: :temporary}]
          |> GenStage.stream()
          |> Enum.take(1)
        end)

      assert :ok = WebhookProducer.send_conn(pid, conn)
      # no response
      refute Task.yield(task, 500)
    end
  end
end

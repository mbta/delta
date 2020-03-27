defmodule Delta.PipelineSupervisorTest do
  @moduledoc false
  use ExUnit.Case
  alias Delta.PipelineSupervisor
  import ExUnit.CaptureLog

  describe "start_link/1" do
    test "can start a pipeline with some basic producers and sinks" do
      bypass = Bypass.open()

      Bypass.expect(bypass, fn conn ->
        Plug.Conn.send_resp(conn, 200, "body")
      end)

      config = %{
        "producers" => %{
          "test" => %{
            "url" => "http://127.0.0.1:#{bypass.port}/",
            "filters" => [["ensure_not_encoded"]]
          },
          "webhook" => %{
            "type" => "webhook"
          }
        },
        "sinks" => %{
          "s3" => %{
            "type" => "s3",
            "bucket" => "bucket",
            "producers" => []
          },
          "log" => %{
            "type" => "log",
            "producers" => ["test"]
          }
        }
      }

      log =
        capture_log(fn ->
          {:ok, pid} = PipelineSupervisor.start_link(config)
          children = Supervisor.count_children(pid)
          assert children.active == 4
          assert children.workers == 4

          [_] =
            [PipelineSupervisor.producer_name("test")]
            |> GenStage.stream()
            |> Enum.take(1)

          Supervisor.stop(pid)
        end)

      assert log =~ "Sink.Log"
    end
  end
end

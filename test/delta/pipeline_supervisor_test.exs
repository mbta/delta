defmodule Delta.PipelineSupervisorTest do
  @moduledoc false
  use ExUnit.Case
  alias Delta.PipelineSupervisor
  import ExUnit.CaptureLog

  describe "start_link/1" do
    test "can start a pipeline with some basic producers and sinks" do
      config = %{
        "producers" => %{
          "test" => %{"url" => "https://cdn.mbta.com/realtime/VehiclePositions.pb"}
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
          assert children.active == 3
          assert children.workers == 3
          # TODO is there a better way to ensure we process one file?
          Process.sleep(1_000)
          Supervisor.stop(pid)
        end)

      assert log =~ "Sink.Log"
    end
  end
end

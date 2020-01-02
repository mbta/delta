defmodule Delta.Sink.LogTest do
  @moduledoc false
  use ExUnit.Case
  alias Delta.File
  alias Delta.Sink.Log
  import ExUnit.CaptureLog

  @sample_file %File{
    updated_at: ~U[2020-01-02T03:04:05Z],
    url: "https://cdn.mbta.com/realtime/Alerts.pb",
    body: "body",
    encoding: :none
  }

  describe "start_link/2" do
    test "logs information about the file" do
      log =
        capture_log([level: :info], fn ->
          assert {:ok, pid} = Log.start_link([], @sample_file)
          assert :ok = await_down(pid)
        end)

      assert log =~ ~s[url="https://cdn.mbta.com/realtime/Alerts.pb"]
      assert log =~ "updated_at=2020-01-02T03:04:05Z"
      assert log =~ "encoding=none"
      assert log =~ "bytes=4"
    end
  end

  defp await_down(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, ^pid, reason} when reason in [:normal, :no_proc] ->
        :ok

      other ->
        {:error, other}
    after
      5_000 ->
        {:error, :timeout}
    end
  end
end

defmodule Delta.ProducerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Delta.Producer

  describe "events" do
    test "returns a %Delta.File{}" do
      {time_usec, result} =
        :timer.tc(fn ->
          take_files(2, url: "https://httpbin.org/uuid", frequency: 500)
        end)

      assert [%Delta.File{}, %Delta.File{}] = result
      # waited at least 500ms between fetches
      assert time_usec >= 500_000
    end

    test "refetches after a cache response" do
      url = response_expectation([{200, "1"}, {304, ""}, {200, "2"}])

      assert [%Delta.File{body: "1"}, %Delta.File{body: "2"}] =
               take_files(2, url: url, frequency: 0, filters: [])
    end

    @tag :capture_log
    test "refetches after an error" do
      url = response_expectation([{500, ""}, {200, "1"}])
      assert [%Delta.File{body: "1"}] = take_files(1, url: url, frequency: 0, filters: [])
    end

    test "does not fetch more than demanded" do
      bypass = Bypass.open()
      Bypass.expect_once(bypass, fn conn -> Plug.Conn.send_resp(conn, 200, "") end)
      url = "http://127.0.0.1:#{bypass.port}"
      {:ok, pid} = Producer.start_link(url: url, frequency: 0)
      assert [%Delta.File{}] = Enum.take(GenStage.stream([{pid, max_demand: 1}]), 1)
    end

    test "by default, always gzip-encodes the files" do
      url = response_expectation([{200, ""}])
      assert [%Delta.File{encoding: :gzip}] = take_files(1, url: url)
    end

    test "can send data to multiple consumers" do
      url = response_expectation([{200, "1"}, {200, "2"}])
      {:ok, pid} = Producer.start_link(url: url, frequency: 200, filters: [])

      task_fn = fn ->
        [pid]
        |> GenStage.stream()
        |> Enum.find(fn %{body: body} -> body == "2" end)
      end

      task_one = Task.async(task_fn)
      task_two = Task.async(task_fn)
      result_one = Task.await(task_one, :infinity)
      result_two = Task.await(task_two, :infinity)
      assert result_one == result_two
    end
  end

  defp take_files(count, opts) do
    {:ok, pid} = Producer.start_link(opts)

    [pid]
    |> GenStage.stream(opts)
    |> Enum.take(count)
  end

  defp response_expectation(responses) do
    bypass = Bypass.open()
    url = "http://127.0.0.1:#{bypass.port}"
    {:ok, pid} = Agent.start_link(fn -> responses end)

    Bypass.expect(bypass, fn conn ->
      {status, body} =
        Agent.get_and_update(pid, fn
          [head | tail] -> {head, tail}
          [] -> {{304, ""}, []}
        end)

      Plug.Conn.send_resp(conn, status, body)
    end)

    url
  end
end

defmodule Delta.Producer.HackneyTest do
  @moduledoc false
  use ExUnit.Case, async: true
  import Plug.Conn, only: [send_resp: 3, get_req_header: 2, put_resp_header: 3]

  alias Delta.Producer.Hackney

  describe "fetch/1" do
    setup do
      bypass = Bypass.open()
      url = "http://127.0.0.1:#{bypass.port}"
      {:ok, conn} = Hackney.new(url)
      {:ok, bypass: bypass, url: url, conn: conn}
    end

    test "can return a basic file", %{bypass: bypass, url: url, conn: conn} do
      Bypass.expect_once(bypass, fn conn ->
        send_resp(conn, 200, "body")
      end)

      assert {:ok, _conn, file} = Hackney.fetch(conn)
      assert file.url == url
      assert %DateTime{} = file.updated_at
      assert file.encoding == :none
      assert file.body == "body"
    end

    test "can return a gzip encoded file", %{bypass: bypass, conn: conn} do
      Bypass.expect_once(bypass, fn conn ->
        assert get_req_header(conn, "accept-encoding") == ["gzip"]

        conn
        |> put_resp_header("Content-Encoding", "gzip")
        |> send_resp(200, "")
      end)

      assert {:ok, _conn, file} = Hackney.fetch(conn)
      assert file.encoding == :gzip
    end

    test "returns :unmodified if the file hasn't changed", %{bypass: bypass, conn: conn} do
      today = "Wed, 01 Jan 2020 00:00:00 GMT"

      Bypass.expect(bypass, fn conn ->
        case get_req_header(conn, "if-none-match") do
          [] ->
            conn
            |> put_resp_header("last-modified", today)
            |> put_resp_header("etag", "etag")
            |> send_resp(200, "")

          ["etag"] ->
            assert get_req_header(conn, "if-modified-since") == [today]

            conn
            |> put_resp_header("etag", "etag2")
            |> send_resp(304, "")

          ["etag2"] ->
            assert get_req_header(conn, "if-modified-since") == [today]
            send_resp(conn, 304, "")
        end
      end)

      {:ok, conn, _file} = Hackney.fetch(conn)
      assert {:unmodified, conn} = Hackney.fetch(conn)
      assert {:unmodified, _conn} = Hackney.fetch(conn)
    end

    test "returns :unmodified if the etag hasn't changed, even with a 200", %{
      bypass: bypass,
      conn: conn
    } do
      Bypass.expect(bypass, fn conn ->
        conn
        |> put_resp_header("etag", "etag")
        |> send_resp(200, "")
      end)

      {:ok, conn, _file} = Hackney.fetch(conn)
      assert {:unmodified, _conn} = Hackney.fetch(conn)
    end

    test "returns an error with an invalid response", %{bypass: bypass, conn: conn} do
      Bypass.expect_once(bypass, fn conn -> send_resp(conn, 500, "") end)
      assert {:error, _conn, {:invalid_status, 500, _}} = Hackney.fetch(conn)
    end

    test "returns an error when something else happens", %{bypass: bypass, conn: conn} do
      Bypass.expect(bypass, fn conn -> send_resp(conn, 200, "") end)
      Bypass.down(bypass)
      assert {:error, _conn, _reason} = Hackney.fetch(conn)
      Bypass.up(bypass)
      assert {:ok, _conn, _file} = Hackney.fetch(conn)
    end
  end
end

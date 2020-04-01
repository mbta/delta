defmodule DeltaWeb.WebhookControllerTest do
  use DeltaWeb.ConnCase

  describe "update/2" do
    @tag :capture_log
    test "returns OK if the webhook suceeds", %{conn: conn} do
      name = "test_webhook"

      {:ok, _pid} =
        Delta.WebhookProducer.start_link(name: Delta.PipelineSupervisor.producer_name(name))

      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post(Routes.webhook_path(conn, :update, name), "")

      assert conn.status == 200
    end

    @tag :capture_log
    test "returns an error if the webhook does not exist", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "text/plain")
        |> post(Routes.webhook_path(conn, :update, "missing"), "")

      assert conn.status == 500
    end
  end
end

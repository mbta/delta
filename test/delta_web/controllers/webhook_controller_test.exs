defmodule DeltaWeb.WebhookControllerTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias DeltaWeb.WebhookController

  describe "update/2" do
    test "returns OK if the webhook suceeds" do
      name = "test_webhook"

      {:ok, _pid} =
        Delta.WebhookProducer.start_link(name: Delta.PipelineSupervisor.producer_name(name))

      conn = conn(:post, "/webhook/#{name}", "")
      conn = WebhookController.update(conn, %{"name" => name})
      assert conn.status == 200
    end

    @tag :capture_log
    test "returns an error if the webhook does not exist" do
      conn = conn(:post, "/webhook/missing", "body")
      conn = WebhookController.update(conn, %{"name" => "missing"})
      assert conn.status == 500
    end
  end
end

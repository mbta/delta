defmodule DeltaWeb.HealthControllerTest do
  use ExUnit.Case, async: true
  use Plug.Test
  alias DeltaWeb.HealthController

  describe "index/2" do
    test "returns 200" do
      conn = conn(:get, "/_health", "")
      conn = HealthController.index(conn, %{})
      assert conn.status == 200
    end
  end
end

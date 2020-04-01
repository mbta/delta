defmodule DeltaWeb.HealthControllerTest do
  use DeltaWeb.ConnCase, async: true

  describe "index/2" do
    @tag :capture_log
    test "returns 200", %{conn: conn} do
      conn = get(conn, Routes.health_path(conn, :index))
      assert conn.status == 200
    end
  end
end

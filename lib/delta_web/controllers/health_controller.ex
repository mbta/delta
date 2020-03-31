defmodule DeltaWeb.HealthController do
  @moduledoc """
  Simple controller to return 200 for health checks.
  """
  use DeltaWeb, :controller

  def index(conn, _params) do
    send_resp(conn, 200, "OK")
  end
end

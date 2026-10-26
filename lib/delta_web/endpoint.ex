defmodule DeltaWeb.Endpoint do
  use Sentry.PlugCapture
  use Phoenix.Endpoint, otp_app: :delta

  plug(Sentry.PlugContext)
  plug(Plug.RequestId)
  plug(Plug.Logger)
  plug(DeltaWeb.Router)
end

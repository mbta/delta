defmodule DeltaWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :delta

  plug(Plug.RequestId)
  plug(Plug.Logger)
  plug(DeltaWeb.Router)

  # callback for runtime configuration
  def init(:supervisor, config) do
    secret_key_base = System.get_env("SECRET_KEY_BASE")

    config =
      if secret_key_base do
        Keyword.put(config, :secret_key_base, secret_key_base)
      else
        config[:secret_key_base] || raise "No SECRET_KEY_BASE ENV var!"
        config
      end

    {:ok, config}
  end
end

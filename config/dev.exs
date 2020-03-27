use Mix.Config

config :delta,
  config_sources: [
    {:system, "DELTA_JSON"},
    "priv/default_configuration,json"
  ]

config :delta, DeltaWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  secret_key_base: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

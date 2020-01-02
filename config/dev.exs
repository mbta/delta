use Mix.Config

config :delta,
  config_sources: [
    {:system, "DELTA_JSON"},
    "priv/default_configuration,json"
  ]

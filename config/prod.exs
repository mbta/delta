use Mix.Config

config :delta,
  config_sources: [
    {:system, "DELTA_JSON"}
  ]

config :delta, DeltaWeb.Endpoint,
  server: true,
  http: [:inet6, port: 4000],
  url: [host: {:system, "HOST"}, port: 443]

config :delta, DeltaWeb.Router, require_https: true

config :sasl, errlog_type: :error

config :logger,
  handle_sasl_reports: true,
  level: :info,
  backends: [:console]

config :logger, :console,
  level: :debug,
  format: "$dateT$time [$level]$levelpad $message\n"

config :ehmon, :report_mf, {:ehmon, :info_report}

config :ex_aws,
  access_key_id: :instance_role,
  secret_access_key: :instance_role

import Config

config :delta,
  default_content_type: "application/octet-stream",
  compressed_content_types: [
    "application/zip"
  ],
  content_type_extensions: %{
    ".json" => "application/json",
    ".pb" => "application/x-protobuf",
    ".zip" => "application/zip"
  }

config :delta, DeltaWeb.Endpoint, url: [host: "localhost"]

config :delta, DeltaWeb.Router, require_https?: false

config :logger, level: :info

config :ex_aws,
  json_codec: Jason,
  http_client: ExAws.Request.Req

config :phoenix, :json_library, Jason

sentry_env = System.get_env("SENTRY_ENV")

if not is_nil(sentry_env) do
  config :sentry,
    filter: DeltaWeb.SentryEventFilter,
    dsn: System.fetch_env!("SENTRY_DSN"),
    environment_name: sentry_env,
    enable_source_code_context: true,
    root_source_code_path: File.cwd!(),
    tags: %{
      env: sentry_env
    },
    included_environments: [sentry_env]

  config :logger, Sentry.LoggerBackend,
    level: :error,
    capture_log_messages: true
end

import_config "#{Mix.env()}.exs"

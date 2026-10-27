import Config

secret_key_base = System.get_env("SECRET_KEY_BASE")

if secret_key_base do
  config DeltaWeb.Endpoint,
    secret_key_base: secret_key_base
end

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

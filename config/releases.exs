import Config

config :delta, DeltaWeb.Endpoint,
  http: [:inet6, port: String.to_integer(System.get_env("PORT") || "4000")]

# See also Delta.SecretsProvider for configuration driven by AWS Secrets Manager

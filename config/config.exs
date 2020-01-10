use Mix.Config

config :delta,
  default_content_type: "application/octet-stream",
  content_type_extensions: %{
    ".json" => "application/json",
    ".pb" => "application/x-protobuf",
    ".zip" => "application/zip"
  }

config :logger, level: :info

config :ex_aws,
  json_codec: Jason

import_config "#{Mix.env()}.exs"

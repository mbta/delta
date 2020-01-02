use Mix.Config

config :logger, level: :info

config :ex_aws,
  json_codec: Jason

import_config "#{Mix.env()}.exs"

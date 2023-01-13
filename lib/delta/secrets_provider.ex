defmodule Delta.SecretsProvider do
  @moduledoc """
  Config.Provider implementation for fetching data from AWS Secrets Manager.
  """
  require Logger
  @behaviour Config.Provider
  @application_requirements [
    :ex_aws_secretsmanager,
    :hackney
  ]

  @type config :: Config.Provider.config()

  @impl Config.Provider
  def init(_), do: :ok

  @impl Config.Provider
  def load(config, _, opts \\ []) do
    prefix = System.get_env("AWS_SECRET_PREFIX")

    load_prefix(config, prefix, opts)
  end

  defp load_prefix(config, prefix, opts) when is_binary(prefix) do
    config
    |> update_config(
      prefix <> "-secret-key-base",
      fn key ->
        [
          delta: [
            {DeltaWeb.Endpoint, [secret_key_base: key]}
          ]
        ]
      end,
      opts
    )
    |> update_config(
      prefix <> "-config",
      fn json ->
        [delta: [config_sources: [json: json]]]
      end,
      opts
    )
  end

  defp load_prefix(config, nil, _opts) do
    config
  end

  @spec secret_string(binary, Keyword.t()) :: {:ok, binary} | :error
  defp secret_string(secret_name, opts) when is_binary(secret_name) do
    ensure_all_started!()
    ex_aws = Keyword.get(opts, :ex_aws, ExAws)
    request = ExAws.SecretsManager.get_secret_value(secret_name)

    case ex_aws.request(request) do
      {:ok, %{"SecretString" => secret}} ->
        {:ok, secret}

      _ ->
        :error
    end
  end

  @spec update_config(config(), binary, (binary -> config()), Keyword.t()) :: config()
  defp update_config(config, secret_name, fun, opts)
       when is_binary(secret_name) and is_function(fun, 1) do
    case secret_string(secret_name, opts) do
      {:ok, value} ->
        Config.Reader.merge(config, fun.(value))

      :error ->
        Logger.info("unable to fetch secret name=#{inspect(secret_name)}")
        config
    end
  end

  defp ensure_all_started! do
    _child_apps =
      for app <- @application_requirements do
        {:ok, _} = Application.ensure_all_started(app)
      end

    :ok
  end
end

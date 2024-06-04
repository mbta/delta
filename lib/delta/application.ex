defmodule Delta.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Delta.Registry},
      {Delta.PipelineSupervisor, config(Application.get_env(:delta, :config_sources))},
      DeltaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Delta.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config([{:system, [_ | _] = env_vars} | rest]) do
    merged_json_config =
      Enum.map(env_vars, fn env_var ->
        if json = System.get_env(env_var) do
          decode(json)
        else
          %{}
        end
      end)
      |> Enum.reduce(%{}, fn next_config, accumulator ->
        DeepMerge.deep_merge(accumulator, next_config)
      end)

    if merged_json_config !== %{} do
      merged_json_config
    else
      config(rest)
    end
  end

  def config([{:system, env_var} | rest]) do
    if json = System.get_env(env_var) do
      decode(json)
    else
      config(rest)
    end
  end

  def config([{:json, json} | _rest]) do
    decode(json)
  end

  def config([filename | rest]) when is_binary(filename) do
    if File.exists?(filename) do
      decode(File.read!(filename))
    else
      config(rest)
    end
  end

  def config([]) do
    %{
      "producers" => [],
      "sinks" => []
    }
  end

  defp decode(json) do
    decoded_config = Jason.decode!(json, strings: :copy)

    if Map.has_key?(decoded_config, "producers") do
      result =
        Enum.reduce(decoded_config["producers"], %{}, fn {k, v}, acc ->
          Map.put(acc, k, process_headers(v))
        end)

      %{decoded_config | "producers" => result}
    else
      decoded_config
    end
  end

  defp process_headers(producer) do
    if Map.has_key?(producer, "headers") do
      modified_headers =
        for {key, raw_value} <- producer["headers"], into: %{} do
          value =
            case raw_value do
              %{"system" => env_var} ->
                System.get_env(env_var)

              raw_value when is_binary(raw_value) ->
                raw_value
            end

          {key, value}
        end

      %{producer | "headers" => modified_headers}
    else
      producer
    end
  end
end

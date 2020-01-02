defmodule Delta.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Delta.Registry},
      {Delta.PipelineSupervisor, config(Application.get_env(:delta, :config_sources))}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Delta.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config([{:system, env_var} | rest]) do
    if json = System.get_env(env_var) do
      decode(json)
    else
      config(rest)
    end
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
    Jason.decode!(json, strings: :copy)
  end
end

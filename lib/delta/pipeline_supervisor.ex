defmodule Delta.PipelineSupervisor do
  @moduledoc """
  Supervisor for the Delta pipeline, both producers and sinks.
  """
  def start_link(%{"producers" => producers, "sinks" => sinks}) do
    Supervisor.start_link(Enum.map(producers, &producer_spec/1) ++ Enum.map(sinks, &sink_spec/1),
      strategy: :one_for_all
    )
  end

  def child_spec(config) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [config]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  defp producer_spec({name, config}) do
    %{
      id: {:producer, name},
      start: {Delta.Producer, :start_link, [producer_opts(name, config)]}
    }
  end

  defp producer_opts(name, config) do
    [
      url: Map.fetch!(config, "url"),
      headers: Map.get(config, "headers", %{}),
      frequency: Map.get(config, "frequency", 60_000),
      name: producer_name(name)
    ]
  end

  defp sink_spec({name, config}) do
    %{
      id: {:sink, name},
      start: {Delta.Sink.ConsumerSupervisor, :start_link, [sink_opts(config)]}
    }
  end

  defp sink_opts(config) do
    {sink_type, sink_opts} = sink_type_opts(config)

    {sink_type,
     sink_opts ++
       [
         subscribe_to: Enum.map(Map.get(config, "producers"), &producer_name/1)
       ]}
  end

  defp sink_type_opts(%{"type" => "s3"} = config) do
    {Delta.Sink.S3,
     bucket: Map.fetch!(config, "bucket"),
     prefix: Map.get(config, "prefix", ""),
     acl: Map.get(config, "acl", "public-read")}
  end

  defp sink_type_opts(%{"type" => "log"}) do
    {Delta.Sink.Log, []}
  end

  @doc false
  def producer_name(name) do
    {:via, Registry, {Delta.Registry, name}}
  end
end

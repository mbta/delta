defmodule Delta.PipelineSupervisor do
  @moduledoc """
  Supervisor for the Delta pipeline, both producers and sinks.
  """

  alias Delta.Producer.Filter

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

  defp producer_spec({name, %{"type" => "webhook"} = config}) do
    opts = [
      authorization: Map.get(config, "authorization"),
      filters: producer_filters(Map.get(config, "filters", [])),
      name: producer_name(name)
    ]

    %{
      id: {:producer, name},
      start: {Delta.WebhookProducer, :start_link, [opts]}
    }
  end

  defp producer_spec({name, %{"type" => "s3"} = config}) do
    opts = [
      bucket: Map.fetch!(config, "bucket"),
      path: Map.fetch!(config, "path"),
      frequency: Map.get(config, "frequency", 60_000),
      filters: producer_filters(Map.get(config, "filters", [])),
      name: producer_name(name)
    ]

    %{
      id: {:producer, name},
      start: {Delta.Producer.S3Producer, :start_link, [opts]}
    }
  end

  defp producer_spec({name, %{"url" => url} = config}) do
    opts = [
      url: url,
      headers: Map.get(config, "headers", %{}),
      frequency: Map.get(config, "frequency", 60_000),
      filters: producer_filters(Map.get(config, "filters", [])),
      name: producer_name(name)
    ]

    %{
      id: {:producer, name},
      start: {Delta.Producer, :start_link, [opts]}
    }
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
     acl: Map.get(config, "acl", "public-read"),
     filename_rewrites:
       Map.get(config, "filename_rewrites", [])
       |> Enum.map(fn x -> for {key, val} <- x, into: %{}, do: {String.to_atom(key), val} end)}
  end

  defp sink_type_opts(%{"type" => "log"}) do
    {Delta.Sink.Log, []}
  end

  @doc false
  def producer_name(name) do
    {:via, Registry, {Delta.Registry, name}}
  end

  defp producer_filters(filters) do
    Enum.map(filters, &do_producer_filter/1) ++ Filter.default_filters()
  end

  defp do_producer_filter([name | args]) do
    # ensure Delta.File is loaded so the atoms have been added to the table
    {:module, _} = Code.ensure_loaded(Delta.File)
    fun_name = String.to_existing_atom(name)
    &apply(Delta.File, fun_name, [&1 | args])
  end
end

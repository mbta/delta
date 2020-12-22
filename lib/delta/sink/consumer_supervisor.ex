defmodule Delta.Sink.ConsumerSupervisor do
  @moduledoc """
  ConsumerSupervisor is responsible for managing the pool of sink
  processes.
  """
  @supervisor_opts ~w(subscribe_to)a

  def start_link({sink_child, opts}) do
    supervisor_opts =
      opts
      |> Keyword.take(@supervisor_opts)
      |> Keyword.put(:strategy, :one_for_one)

    opts = Keyword.drop(opts, @supervisor_opts)

    children = [
      %{
        id: sink_child,
        start: {sink_child, :start_link, [opts]},
        restart: :temporary
      }
    ]

    ConsumerSupervisor.start_link(children, supervisor_opts)
  end
end

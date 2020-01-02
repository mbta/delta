defmodule Delta.Sink.Log do
  @moduledoc """
  Sink which logs information about the file.
  """
  alias Delta.File
  require Logger

  def start_link(_config, file) do
    Task.start_link(__MODULE__, :log, [file])
  end

  def log(%File{} = file) do
    _ =
      Logger.info(
        "#{__MODULE__} url=#{inspect(file.url)} updated_at=#{DateTime.to_iso8601(file.updated_at)} encoding=#{
          file.encoding
        } bytes=#{byte_size(file.body)}"
      )

    :ok
  end
end

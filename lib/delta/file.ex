defmodule Delta.File do
  @moduledoc """
  Struct representing a file fetched from a remote server.
  """
  defstruct [
    :updated_at,
    :url,
    :body,
    encoding: :none
  ]

  @type t :: %__MODULE__{
          updated_at: DateTime.t(),
          url: binary,
          body: binary,
          encoding: encoding
        }
  @type encoding :: :none | :gzip

  @doc "Ensure that the file is GZip-encoded."
  @spec ensure_gzipped(t()) :: t()
  def ensure_gzipped(%__MODULE__{encoding: :none} = file) do
    encoded_body = :zlib.gzip(file.body)
    %{file | body: encoded_body, encoding: :gzip}
  end

  def ensure_gzipped(%__MODULE__{encoding: :gzip} = file) do
    file
  end
end

defmodule Delta.File do
  @moduledoc """
  Struct representing a file fetched from a remote server.
  """
  defstruct [
    :updated_at,
    :url,
    :body,
    content_type: Application.get_env(:delta, :default_content_type),
    encoding: :none
  ]

  @type t :: %__MODULE__{
          updated_at: DateTime.t(),
          url: binary,
          body: binary,
          content_type: binary,
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

  @doc "Ensure that the file has a content type"
  @spec ensure_content_type(t()) :: t()
  def ensure_content_type(%__MODULE__{content_type: ct} = file) when is_binary(ct) do
    file
  end

  def ensure_content_type(%__MODULE__{} = file) do
    extension = Path.extname(file.url)
    content_type = content_type_of_extension(extension)
    %{file | content_type: content_type}
  end

  defp content_type_of_extension(extension) do
    types = Application.get_env(:delta, :content_type_extensions)
    Map.get_lazy(types, extension, fn -> Application.get_env(:delta, :default_content_type) end)
  end
end

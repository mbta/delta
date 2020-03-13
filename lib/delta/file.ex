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

  @already_compressed_content_types Application.get_env(:delta, :compressed_content_types)

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
  def ensure_gzipped(%__MODULE__{content_type: ct, encoding: :none} = file)
      when ct not in @already_compressed_content_types do
    encoded_body = :zlib.gzip(file.body)
    %{file | body: encoded_body, encoding: :gzip}
  end

  def ensure_gzipped(%__MODULE__{} = file) do
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

  @doc "Split a JSON file into sub files, based on an access path"
  @spec json_split_path(t(), term) :: [t()]
  def json_split_path(%__MODULE__{body: body} = file, path) do
    with {:ok, json} <- Jason.decode(body),
         parts when is_list(parts) <- get_in(json, List.wrap(path)) do
      for part <- parts do
        %{file | body: Jason.encode!(part)}
      end
    else
      _ -> file
    end
  end

  @doc "Renames a JSON file, based on an access path"
  @spec json_rename(t(), term) :: t()
  def json_rename(%__MODULE__{body: body} = file, path) do
    with {:ok, json} <- Jason.decode(body),
         name <- get_in(json, List.wrap(path)) do
      %{file | url: "#{file.url}\##{name}"}
    else
      _ -> file
    end
  end
end

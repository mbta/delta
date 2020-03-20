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

  @doc """
  Ensure that the file is not encoded.

  This can be useful if other filters further down the chain need to interact
  with a normal file.
  """
  @spec ensure_not_encoded(t()) :: t()
  def ensure_not_encoded(%__MODULE__{encoding: :gzip} = file) do
    encoded_body = :zlib.gunzip(file.body)
    %{file | body: encoded_body, encoding: :none}
  end

  def ensure_not_encoded(%__MODULE__{} = file) do
    file
  end

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
  def json_split_path(%__MODULE__{} = file, path) do
    with {:ok, parts} when is_list(parts) <- get_json_path(file, path) do
      for part <- parts do
        %{file | body: Jason.encode!(part)}
      end
    end
  end

  @doc "Renames a JSON file, based on an access path"
  @spec json_rename(t(), term) :: t()
  def json_rename(%__MODULE__{} = file, path) do
    with {:ok, name} when name != nil <- get_json_path(file, path) do
      %{file | url: "#{file.url}\##{name}"}
    end
  end

  @doc "Gets the updated_at time from a JSON path"
  @spec json_updated_at(t(), term) :: t()
  def json_updated_at(%__MODULE__{} = file, path) do
    with {:ok, time} when time != nil <- get_json_path(file, path),
         {:ok, time} <- decode_time(time) do
      %{file | updated_at: time}
    else
      _ -> file
    end
  end

  @spec get_json_path(t(), term) :: {:ok, term} | t()
  defp get_json_path(%__MODULE__{body: body} = file, path) do
    case Jason.decode(body) do
      {:ok, json} ->
        value = get_in(json, List.wrap(path))
        {:ok, value}

      _ ->
        # return the file unmodified
        file
    end
  end

  @unix_ms_cutoff 1_000_000_000_000

  @doc """
  Decodes some types of time values into DateTime structs.

  ## Examples

  iex> File.decode_time(1567094515535)
  {:ok, ~U[2019-08-29 16:01:55.535Z]}


  iex> File.decode_time(1567094515)
  {:ok, ~U[2019-08-29 16:01:55Z]}

  iex> File.decode_time("2019-08-29T16:01:55Z")
  {:ok, ~U[2019-08-29 16:01:55Z]}

  iex> File.decode_time("invalid")
  :error
  """
  @spec decode_time(term) :: {:ok, DateTime.t()} | :error
  def decode_time(term)

  def decode_time(binary) when is_binary(binary) do
    case DateTime.from_iso8601(binary) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, _} -> :error
    end
  end

  def decode_time(unix_ms) when is_integer(unix_ms) and unix_ms >= @unix_ms_cutoff do
    case DateTime.from_unix(unix_ms, :millisecond) do
      {:ok, dt} -> {:ok, dt}
      {:error, _} -> :error
    end
  end

  def decode_time(unix) when is_integer(unix) do
    case DateTime.from_unix(unix) do
      {:ok, dt} ->
        {:ok, dt}

      {:error, _} ->
        :error
    end
  end
end

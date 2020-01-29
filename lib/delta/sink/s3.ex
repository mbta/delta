defmodule Delta.Sink.S3 do
  @moduledoc """
  Sink which writes files to an S3 bucket.
  """
  alias Delta.File
  alias ExAws.S3
  require Logger

  @spec start_link(Keyword.t(), File.t()) :: GenServer.on_start()
  def start_link(config, %File{} = file) when is_list(config) do
    Task.start_link(__MODULE__, :upload_to_s3, [Map.new(config), file])
  end

  @spec upload_to_s3(map, File.t()) :: :ok
  def upload_to_s3(config, file) do
    ex_aws = Map.get(config, :ex_aws, ExAws)
    full_filename = Path.join(config.prefix, build_filename(file))

    put_config = [
      acl: config.acl,
      content_encoding: content_encoding(file),
      content_type: content_type(file)
    ]

    request = S3.put_object(config.bucket, full_filename, file.body, put_config)
    response = ex_aws.request(request)

    _ = log_response(config, full_filename, file, request, response)

    :ok
  end

  defp build_filename(%File{} = file) do
    iso_dt = DateTime.to_iso8601(file.updated_at)
    <<year::binary-4, ?-, month::binary-2, ?-, day::binary-2, _::binary>> = iso_dt
    encoded_url = String.replace(file.url, ~R/[^A-Za-z0-9._~]+/, "_")

    year <>
      "/" <> month <> "/" <> day <> "/" <> iso_dt <> "_" <> encoded_url <> encoding_suffix(file)
  end

  defp content_encoding(%File{encoding: :gzip}), do: "gzip"
  defp content_encoding(%File{encoding: :none}), do: "identity"

  defp encoding_suffix(%File{encoding: :gzip}), do: ".gz"
  defp encoding_suffix(%File{}), do: ""

  defp content_type(%File{} = file) do
    if content_type = file.content_type do
      content_type
    else
      Application.get_env(:delta, :default_content_type)
    end
  end

  defp log_response(config, full_filename, file, request, response) do
    level =
      case response do
        {:ok, _} ->
          :info

        {:error, _} ->
          :warn
      end

    Logger.log(level, fn ->
      response_text =
        case response do
          {:ok, _} ->
            "uploaded"

          {:error, reason} ->
            "failed to upload reason=#{inspect(reason)} request=#{inspect(request)}"
        end

      "#{__MODULE__} #{response_text} bucket=#{config.bucket} path=#{full_filename} content_type=#{
        inspect(file.content_type)
      } bytes=#{byte_size(file.body)}"
    end)
  end
end

defmodule Delta.Sink.S3 do
  @moduledoc """
  Sink which writes files to an S3 bucket.
  """
  alias Delta.File
  alias ExAws.S3
  require Logger

  def start_link(config, file) do
    Task.start_link(__MODULE__, :upload_to_s3, [config, file])
  end

  def upload_to_s3(config, file) do
    ex_aws = Map.get(config, :ex_aws, ExAws)
    full_filename = Path.join(config.prefix, build_filename(file))

    put_config = [
      acl: config.acl,
      content_encoding: content_encoding(file),
      content_type: content_type(file)
    ]

    config.bucket
    |> S3.put_object(full_filename, file.body, put_config)
    |> ex_aws.request!

    _ =
      Logger.info(
        "#{__MODULE__} uploaded bucket=#{config.bucket} path=#{full_filename} bytes=#{
          byte_size(file.body)
        }"
      )

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

  defp content_type(%File{url: url}) do
    do_content_type(Path.extname(url))
  end

  defp do_content_type(".json"), do: "application/json"
  defp do_content_type(".pb"), do: "application/x-protobuf"
  defp do_content_type(_), do: "application/octet-stream"
end

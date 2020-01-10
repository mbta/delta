defmodule Delta.FileTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Delta.File

  describe "ensure_gzipped/1" do
    test "does nothing for already encoded files" do
      file = %File{encoding: :gzip}
      assert File.ensure_gzipped(file) == file
    end

    test "gzip encodes a regular file" do
      file = %File{body: "1234"}
      encoded = File.ensure_gzipped(file)
      assert encoded.encoding == :gzip
      assert :zlib.gunzip(encoded.body) == file.body
    end
  end

  describe "ensure_content_type" do
    test "does nothing for files with a content type" do
      file = %File{content_type: "text/plain"}
      assert File.ensure_content_type(file) == file
    end

    test "builds a content type from the URL" do
      file = %File{url: "https://cdn.mbta.com/MBTA_GTFS.zip", content_type: nil}
      file = File.ensure_content_type(file)
      assert file.content_type == "application/zip"
    end

    test "defaults the content type to application/octet-stream" do
      file = %File{url: "unknown", content_type: nil}
      file = File.ensure_content_type(file)
      assert file.content_type == "application/octet-stream"
    end
  end
end

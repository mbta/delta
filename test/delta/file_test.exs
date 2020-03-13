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

    test "does not gzip encode a ZIP file" do
      file = %File{content_type: "application/zip"}
      assert File.ensure_gzipped(file) == file
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

  describe "json_split_path" do
    test "splits a file into parts based on the path" do
      json = ~s(
        {
          "a": {
            "b": [1, 2]
          }
        })
      file = %File{body: json}
      assert [one, two] = File.json_split_path(file, ["a", "b"])
      assert one.body == "1"
      assert two.body == "2"
    end

    test "returns the file unmodified if it doesn't parse" do
      file = %File{body: "not json"}
      assert File.json_split_path(file, ["a"]) == file
    end
  end

  describe "json_rename" do
    test "renames a file based on a path" do
      json = ~s({"id": 1})
      file = %File{url: "https://www.mbta.com/hello", body: json}
      file = File.json_rename(file, "id")
      assert file.url == "https://www.mbta.com/hello#1"
    end

    test "returns the file unmodified if it doesn't parse" do
      file = %File{body: "not json"}
      assert File.json_rename(file, ["a"]) == file
    end
  end
end

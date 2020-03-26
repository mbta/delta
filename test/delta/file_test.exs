defmodule Delta.FileTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Delta.File

  doctest File

  describe "ensure_not_encoded/1" do
    test "does nothing for not encoded files" do
      file = %File{encoding: :none}
      assert File.ensure_not_encoded(file) == file
    end

    test "gzip decodes an encoded file" do
      file = %File{body: :zlib.gzip("1234"), encoding: :gzip}
      assert %File{body: "1234", encoding: :none} = File.ensure_not_encoded(file)
    end
  end

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

    test "returns nothing if it doesn't parse" do
      file = %File{body: "not json"}
      assert File.json_split_path(file, ["a"]) == []
    end
  end

  describe "json_rename" do
    test "renames a file based on a path" do
      json = ~s({"id": 1})
      file = %File{url: "https://www.mbta.com/hello", body: json}
      [file] = File.json_rename(file, "id")
      assert file.url == "https://www.mbta.com/hello#1"
    end

    test "returns nothing if it doesn't parse" do
      file = %File{body: "not json"}
      assert File.json_rename(file, ["a"]) == []
    end
  end

  describe "json_updated_at/2" do
    test "adjusts the file's updated_at based on a path" do
      json = ~s({"time": 0})
      file = %File{url: "https://www.mbta.com/hello", body: json, updated_at: DateTime.utc_now()}
      [file] = File.json_updated_at(file, "time")
      assert file.updated_at == DateTime.from_unix!(0)
    end

    test "returns nothing if it doesn't parse" do
      file = %File{body: "not json"}
      assert File.json_updated_at(file, ["a"]) == []

      file = %File{body: ~s({"a": "not a date"})}
      assert File.json_updated_at(file, ["a"]) == []
    end
  end
end

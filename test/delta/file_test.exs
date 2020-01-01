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
end

defmodule Delta.Producer.Filter do
  @moduledoc """
  Process the Files made by Producers into zero or more different Files.
  """

  alias Delta.File

  @type t :: (File.t() -> File.t() | [File.t()])

  def default_filters do
    [&File.ensure_content_type/1, &File.ensure_gzipped/1]
  end

  @doc "Apply a list of filters to a list of files"
  @spec apply_filters([File.t()], [t()]) :: [File.t()]
  def apply_filters(files, [filter | rest]) do
    files =
      Enum.flat_map(files, fn file ->
        file
        |> filter.()
        |> List.wrap()
      end)

    apply_filters(files, rest)
  end

  def apply_filters(files, []) do
    files
  end
end

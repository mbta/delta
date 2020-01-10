defmodule Delta.Producer.HTTP do
  @moduledoc """
  Behavior for the HTTP library used by Delta.Producer.

  This wrapper handles caching, as well as turning the response into a Delta.File.
  """
  @type t :: term
  @callback new(binary) :: {:ok, t()}
  @callback fetch(t()) :: {:ok, t(), Delta.File.t()} | {:unmodified, t()} | {:error, t(), term}
  @callback stream(t(), term) :: {:ok, t(), [Delta.File.t()]} | :unknown
end

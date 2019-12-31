defmodule Delta.File do
  @moduledoc """
  Struct representing a file fetched from a remote server.
  """
  defstruct [
    :updated_at,
    :url,
    :body,
    encoding: :none
  ]

  @type t :: %__MODULE__{
          updated_at: DateTime.t(),
          url: binary,
          body: binary,
          encoding: encoding
        }
  @type encoding :: :none | :gzip
end

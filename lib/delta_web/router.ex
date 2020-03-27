defmodule DeltaWeb.Router do
  use DeltaWeb, :router

  pipeline :webhook do
    if Application.get_env(:delta, __MODULE__)[:require_https?] do
      plug(Plug.SSL, rewrite_on: [:x_forwarded_proto])
    end

    plug(:accepts, ["json"])
  end

  scope "/", DeltaWeb do
    pipe_through([:webhook])
  end
end

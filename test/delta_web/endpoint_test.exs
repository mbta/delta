defmodule DeltaWeb.EndpointTest do
  use ExUnit.Case, async: true

  describe "init/2" do
    test "can load SECRET_KEY_BASE from the environment" do
      System.put_env("SECRET_KEY_BASE", "not_secret")
      {:ok, config} = DeltaWeb.Endpoint.init(:supervisor, [])
      assert [secret_key_base: "not_secret"] = config
    end
  end
end

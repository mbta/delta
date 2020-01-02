defmodule Delta.ApplicationTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Delta.Application

  describe "config/1" do
    test "can get the default configuration" do
      assert %{"producers" => %{}, "sinks" => %{}} =
               Application.config([
                 {:system, "DOES_NOT_EXIST"},
                 "priv/missing_file",
                 "priv/default_configuration.json"
               ])
    end

    test "can get configuration from the environment" do
      expected = %{"producers" => %{}, "sinks" => %{"log" => %{"type" => "log"}}}
      env_var = "DELTA_APPLICATION_TEST"
      json = Jason.encode!(expected)
      System.put_env(env_var, json)
      assert ^expected = Application.config([{:system, env_var}])
    end
  end
end

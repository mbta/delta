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

    test "can get configurations from the environment, merged" do
      expected_first = %{"producers" => %{}, "sinks" => %{"log" => %{"type" => "log"}}}
      env_var_first = "DELTA_APPLICATION_TEST_1"
      expected_second = %{"sinks" => %{"log_2" => %{"type" => "log"}}}
      env_var_second = "DELTA_APPLICATION_TEST_2"

      final_expected = %{
        "producers" => %{},
        "sinks" => %{"log" => %{"type" => "log"}, "log_2" => %{"type" => "log"}}
      }

      json_first = Jason.encode!(expected_first)
      json_second = Jason.encode!(expected_second)
      System.put_env(env_var_first, json_first)
      System.put_env(env_var_second, json_second)
      assert ^final_expected = Application.config([{:system, [env_var_first, env_var_second]}])
    end

    test "can get configuration from raw JSON" do
      expected = %{"producers" => %{}, "sinks" => %{"log" => %{"type" => "log"}}}
      json = Jason.encode!(expected)
      assert ^expected = Application.config([{:json, json}])
    end
  end
end

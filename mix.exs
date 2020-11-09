defmodule Delta.MixProject do
  use Mix.Project

  def project do
    [
      app: :delta,
      version: "0.1.0",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases(),
      dialyzer: [
        plt_add_deps: :transitive,
        flags: [
          :race_conditions,
          :unmatched_returns
        ]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Delta.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:gen_stage, "~> 1.0"},
      {:hackney, "~> 1.15"},
      {:cowlib, "~> 2.8"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws_secretsmanager, "~> 2.0"},
      {:jason, "~> 1.0"},
      {:credo, "~> 1.5.1", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.5"},
      {:phoenix_html, "~> 2.14"},
      {:plug_cowboy, "~> 2.2"},
      {:excoveralls, "~> 0.10", only: :test, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:bypass, "~> 1.0", only: :test},
      {:ehmon, git: "https://github.com/mbta/ehmon.git", branch: "master", only: :prod}
    ]
  end

  defp releases do
    [
      delta: [
        include_executables_for: [:unix],
        config_providers: [{Delta.SecretsProvider, []}]
      ]
    ]
  end
end

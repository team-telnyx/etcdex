defmodule EtcdEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :etcdex,
      version: "1.1.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      name: "EtcdEx",
      source_url: "https://github.com/team-telnyx/etcdex",
      description: description(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    other_extra_applications =
      if Mix.env() == :test,
        do: [:inets],
        else: []

    [extra_applications: [:logger] ++ other_extra_applications]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:mint, "~> 1.0"},
      {:protobuf, "~> 0.10"},
      {:connection, "~> 1.1"},
      {:stream_data, "~> 0.5", only: :test},
      {:excoveralls, "~> 0.10", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      protoc:
        for file <- [
              "auth.proto",
              "gogo.proto",
              "kv.proto",
              "router.proto"
            ] do
          "cmd protoc --elixir_out=./lib/etcd_ex/protos -Iprotos protos/#{file}"
        end
    ]
  end

  defp description do
    """
    An Elixir Etcd client.
    """
  end

  defp package do
    [
      maintainers: [
        "Guilherme Versiani <guilherme@telnyx.com>",
        "Michał Szajbe <michals@telnyx.com>",
        "Thanya Nitithatsanakul <thanya@telnyx.com>"
      ],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/team-telnyx/etcdex"},
      files: ~w"lib mix.exs README.md LICENSE"
    ]
  end
end

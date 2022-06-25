defmodule EtcdEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :etcdex,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      name: "EtcdEx",
      source_url: "https://github.com/team-telnyx/etcdex",
      description: description()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mint, "~> 1.0"},
      {:protobuf, "~> 0.10"},
      {:connection, "~> 1.1"},
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

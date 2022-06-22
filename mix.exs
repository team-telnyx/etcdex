defmodule EtcdEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :etcdex,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      {:eetcd, "~> 0.3"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
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
        "Michał Szajbe <michals@telnyx.com>"
      ],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/team-telnyx/etcdex"},
      files: ~w"lib mix.exs README.md LICENSE"
    ]
  end
end

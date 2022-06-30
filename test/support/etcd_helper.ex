defmodule EtcdHelper do
  @moduledoc """
  This module helps finding and starting etcd as a background process.
  """

  @github_url "https://github.com/etcd-io/etcd/releases/download"
  @etcd_version "v3.5.4"

  @open_port_opts [:exit_status, :binary, :stream, :stderr_to_stdout]

  def start_etcd(etcd_path, args \\ []) do
    opts =
      case args do
        [] -> @open_port_opts
        _ -> @open_port_opts ++ [args: args]
      end

    Port.open({:spawn, etcd_path}, opts)
  end

  def get_etcd do
    case System.find_executable("etcd") do
      nil ->
        case os() do
          "linux" ->
            download_linux_etcd()

          "darwin" ->
            download_darwin_etcd()
        end

        {"test/bin/etcd", "test/bin/etcdctl"}

      etcd_executable ->
        {etcd_executable, System.find_executable("etcdctl")}
    end
  end

  def download_linux_etcd do
    filename = "etcd-#{@etcd_version}-linux-#{arch()}.tar.gz"

    if not File.exists?("test/bin/#{filename}") do
      url = "#{@github_url}/#{@etcd_version}/#{filename}"

      {:ok, resp} = :httpc.request(:get, {String.to_charlist(url), []}, [], body_format: :binary)

      {{_, 200, _}, _headers, body} = resp

      File.mkdir_p!("test/bin")
      File.write!("test/bin/#{filename}", body)
    end

    if not File.exists?("test/bin/etcd") or not File.exists?("test/bin/etcdctl") do
      {_, 0} =
        System.cmd("tar", [
          "xzvf",
          "test/bin/#{filename}",
          "-C",
          "test/bin",
          "--strip-components=1"
        ])
    end
  end

  def download_darwin_etcd do
    filename = "etcd-#{@etcd_version}-darwin-#{arch()}.zip"

    if not File.exists?("test/bin/#{filename}") do
      url = "#{@github_url}/#{@etcd_version}/#{filename}"

      {:ok, resp} = :httpc.request(:get, {String.to_charlist(url), []}, [], body_format: :binary)

      {{_, 200, _}, _headers, body} = resp

      File.mkdir_p!("test/bin")
      File.write!("test/bin/#{filename}", body)
    end

    if not File.exists?("test/bin/etcd") or not File.exists?("test/bin/etcdctl") do
      {_, 0} =
        System.cmd("unzip", [
          "test/bin/#{filename}",
          "-d",
          "test/bin"
        ])
    end
  end

  def arch do
    {output, _exit} = System.cmd("uname", ["-m"])

    output
    |> String.trim()
    |> String.downcase()
    |> case do
      "x86_64" -> "amd64"
      "aarch64" -> "arm64"
      other -> other
    end
  end

  def os do
    {output, 0} = System.cmd("uname", ["-s"])

    output
    |> String.trim()
    |> String.downcase()
  end
end

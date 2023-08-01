defmodule EtcdCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require accessing an etcd instance.
  """

  use ExUnit.CaseTemplate

  @container_name "etcdex-test"
  @start_args [
    "run",
    "--name",
    @container_name,
    "--env",
    "ALLOW_NONE_AUTHENTICATION=yes",
    "--publish",
    "2379:2379",
    "--publish",
    "2380:2380",
    "--volume",
    "#{Path.expand("tmp")}:/bitnami/etcd/data",
    "--detach",
    "--rm",
    "bitnami/etcd"
  ]

  using do
    quote do
      # Import conveniences for testing with etcd
      import EtcdCase
    end
  end

  @doc """
  Starts etcd in the background.
  """
  @spec start_etcd() :: container_id :: binary()
  def start_etcd do
    File.mkdir_p("tmp")

    {container_id, 0} =
      case System.cmd("docker", @start_args) do
        {_, 125} ->
          # maybe container is still running, stop and try again
          stop_etcd()
          System.cmd("docker", @start_args)

        res ->
          res
      end

    :timer.sleep(5000)

    String.trim(container_id)
  end

  @doc """
  Stop the background etcd instance.
  """
  def stop_etcd do
    System.cmd("docker", ["stop", @container_name])
  end

  @doc """
  Removes etcd container
  """
  def remove_etcd_container do
    System.cmd("docker", ["rm", @container_name])
    File.rm_rf("tmp")
  end

  @doc """
  Runs etcdctl command.
  """
  @spec etcdctl(args :: [String.t()]) :: {Collectable.t(), exit_status :: non_neg_integer()}
  def etcdctl(args \\ []) do
    System.cmd("docker", ["exec", @container_name, "etcdctl" | args])
  end
end

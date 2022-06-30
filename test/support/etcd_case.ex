defmodule EtcdCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require accessing an etcd instance.
  """

  use ExUnit.CaseTemplate

  @etcd_tools EtcdHelper.get_etcd()
  @etcd_path elem(@etcd_tools, 0)
  @etcdctl_path elem(@etcd_tools, 1)

  using do
    quote do
      # Import conveniences for testing with etcd
      import EtcdCase
    end
  end

  @doc """
  Starts etcd in the background.
  """
  @spec start_etcd(args :: [String.t()]) :: {port, os_pid :: integer}
  def start_etcd(args \\ []) do
    port = EtcdHelper.start_etcd(@etcd_path, args)

    os_pid =
      case Port.info(port, :os_pid) do
        {_, os_pid} -> os_pid
        _ -> nil
      end

    {port, os_pid}
  end

  @doc """
  Stop the background etcd instance.
  """
  @spec stop_etcd({port, os_pid :: integer}) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def stop_etcd({_port, os_pid}) do
    System.cmd("kill", ["#{os_pid}"])
  end

  @doc """
  Runs etcdctl command.
  """
  @spec etcdctl(args :: [String.t()]) :: {Collectable.t(), exit_status :: non_neg_integer()}
  def etcdctl(args \\ []) do
    System.cmd(@etcdctl_path, args)
  end
end

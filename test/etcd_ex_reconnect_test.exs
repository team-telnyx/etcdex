defmodule EtcdExReconnectTest do
  use EtcdCase, async: false

  test "simple reconnect" do
    # Clean up any remainings from past executions
    File.rm_rf!("default.etcd")

    proc_ref = start_etcd()

    Process.sleep(1_000)

    conn =
      start_supervised!(
        {EtcdEx, [backoff: 1_000, keep_alive_interval: 1_000, keep_alive_timeout: 500]}
      )

    assert {:ok, _} = EtcdEx.put(conn, "foo", "bar")

    stop_etcd(proc_ref)

    Process.sleep(5_000)

    proc_ref = start_etcd()

    # give enough time for EtcdEx to reconnect
    Process.sleep(3_000)

    assert {:ok, %{kvs: [%{value: "bar"}]}} = EtcdEx.get(conn, "foo")

    stop_etcd(proc_ref)
  end
end

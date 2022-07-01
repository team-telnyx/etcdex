defmodule EtcdExReconnectTest do
  use EtcdCase, async: false

  test "simple reconnect" do
    # Clean up any remnants from past executions
    File.rm_rf!("default.etcd")

    proc_ref = start_etcd()

    Process.sleep(1_000)

    conn =
      start_supervised!(
        {EtcdEx, [backoff: 500, keep_alive_interval: 1_000, keep_alive_timeout: 500]}
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

  test "reconnect watches" do
    # Clean up any remnants from past executions
    File.rm_rf!("default.etcd")

    proc_ref = start_etcd()

    Process.sleep(1_000)

    conn =
      start_supervised!(
        {EtcdEx, [backoff: 500, keep_alive_interval: 1_000, keep_alive_timeout: 500]}
      )

    assert {:ok, _} = EtcdEx.put(conn, "foo", "bar")

    assert {:ok, watch_ref} = EtcdEx.watch(conn, self(), "foo")

    stop_etcd(proc_ref)

    Process.sleep(5_000)

    proc_ref = start_etcd()

    # give enough time for EtcdEx to reconnect
    Process.sleep(10_000)

    assert {:ok, _} = EtcdEx.put(conn, "foo", "baz")

    assert_receive {:etcd_watch_created, ^watch_ref}

    assert_receive {:etcd_watch_notify, ^watch_ref,
                    %{events: [%{type: :PUT, kv: %{value: "baz"}}]}}

    stop_etcd(proc_ref)
  end
end

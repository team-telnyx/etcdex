defmodule EtcdExReconnectTest do
  use EtcdCase, async: false

  setup do
    start_etcd()

    on_exit(fn ->
      stop_etcd()
      remove_etcd_container()
    end)

    # Make sure etcd is totally empty
    {_, 0} = etcdctl(["del", "", "--prefix"])

    :ok
  end

  test "simple reconnect" do
    conn =
      start_supervised!(
        {EtcdEx, [backoff: 500, keep_alive_interval: 1_000, keep_alive_timeout: 500]}
      )

    assert {:ok, _} = EtcdEx.put(conn, "foo", "bar")

    stop_etcd()

    Process.sleep(5_000)

    start_etcd()

    # give enough time for EtcdEx to reconnect
    Process.sleep(3_000)

    assert {:ok, %{kvs: [%{value: "bar"}]}} = EtcdEx.get(conn, "foo")
  end

  test "reconnect watches" do
    conn =
      start_supervised!(
        {EtcdEx, [backoff: 500, keep_alive_interval: 1_000, keep_alive_timeout: 500]}
      )

    assert {:ok, _} = EtcdEx.put(conn, "foo", "bar")

    assert {:ok, watch_ref} = EtcdEx.watch(conn, self(), "foo")
    assert_receive {:etcd_watch_created, ^watch_ref}

    stop_etcd()

    Process.sleep(5_000)

    start_etcd()

    # give enough time for EtcdEx to reconnect
    Process.sleep(10_000)

    assert {:ok, _} = EtcdEx.put(conn, "foo", "baz")

    assert_receive {:etcd_watch_created, ^watch_ref}

    assert_receive {:etcd_watch_notify, ^watch_ref,
                    %{events: [%{type: :PUT, kv: %{value: "baz"}}]}}
  end
end

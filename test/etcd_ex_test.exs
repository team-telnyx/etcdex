defmodule EtcdExTest do
  use EtcdCase, async: false
  use ExUnitProperties

  setup_all do
    # Clean up any remainings from past executions
    File.rm_rf!("default.etcd")

    proc_ref = start_etcd()
    on_exit(fn -> stop_etcd(proc_ref) end)

    :ok
  end

  setup do
    # Make sure etcd is totally empty
    {_, 0} = etcdctl(["del", "", "--prefix"])

    {:ok, conn: start_supervised!(EtcdEx)}
  end

  describe "get" do
    for {kvs, get_params, expected} <- [
          # no key
          {
            [
              {"foo", "bar"}
            ],
            ["baz"],
            []
          },
          # single key
          {
            [
              {"foo", "bar"}
            ],
            ["foo"],
            [
              {"foo", "bar"}
            ]
          },
          # prefix key
          {
            [
              {"key1", "1"},
              {"key2", "2"},
              {"key3", "3"},
              {"kez", ""}
            ],
            ["key", [prefix: true]],
            [
              {"key1", "1"},
              {"key2", "2"},
              {"key3", "3"}
            ]
          },
          # from key
          {
            [
              {"kex", "0"},
              {"key1", "1"},
              {"key2", "2"},
              {"key3", "3"},
              {"kez", "4"}
            ],
            ["key", [from_key: true]],
            [
              {"key1", "1"},
              {"key2", "2"},
              {"key3", "3"},
              {"kez", "4"}
            ]
          },
          # from key + limit
          {
            [
              {"kex", "0"},
              {"key1", "1"},
              {"key2", "2"},
              {"key3", "3"},
              {"kez", "4"}
            ],
            ["key", [from_key: true, limit: 1]],
            [
              {"key1", "1"}
            ]
          },
          # from key + sort
          {
            [
              {"kex", "0"},
              {"key1", "1"},
              {"key2", "2"},
              {"key3", "3"},
              {"kez", "4"}
            ],
            ["key3", [from_key: true, sort: {:KEY, :DESCEND}]],
            [
              {"kez", "4"},
              {"key3", "3"}
            ]
          },
          # from key + keys only
          {
            [
              {"kex", "0"},
              {"key1", "1"},
              {"key2", "2"},
              {"key3", "3"},
              {"kez", "4"}
            ],
            ["key3", [from_key: true, keys_only: true]],
            [
              {"key3", ""},
              {"kez", ""}
            ]
          },
          # from key + count only
          # this results in an empty kvs
          {
            [
              {"kex", "0"},
              {"key1", "1"},
              {"key2", "2"},
              {"key3", "3"},
              {"kez", "4"}
            ],
            ["key", [from_key: true, count_only: true]],
            []
          }
        ] do
      @tag params: {kvs, get_params, expected}
      test "#{inspect(get_params)} in #{inspect(kvs)}", %{
        conn: conn,
        params: params
      } do
        {kvs, get_params, expected} = params

        for {key, value} <- kvs do
          {_, 0} = etcdctl(["put", key, value])
        end

        {:ok, %{kvs: kvs}} = apply(EtcdEx, :get, [conn] ++ get_params)

        assert expected == Enum.map(kvs, &{&1.key, &1.value})
      end
    end

    @tag timeout: :infinity
    test "to count", %{conn: conn} do
      key_value_generator = map_of(string(?a..?z, min_length: 1), string(?a..?z, min_length: 1))

      check all(kvs <- key_value_generator, max_runs: 20) do
        for {key, value} <- kvs do
          {_, 0} = etcdctl(["put", key, value])
        end

        {:ok, %{count: count}} = EtcdEx.get(conn, <<0>>, from_key: true, count_only: true)
        assert count == Enum.count(kvs)

        etcdctl(["del", "", "--from-key"])
      end
    end

    test "with revision", %{conn: conn} do
      {_, 0} = etcdctl(["put", "foo", "bar"])
      {:ok, %{header: %{revision: revision}}} = EtcdEx.get(conn, "foo")
      {_, 0} = etcdctl(["put", "foo", "baz"])

      assert {:ok, %{kvs: [%{key: "foo", value: "bar"}]}} =
               EtcdEx.get(conn, "foo", revision: revision)

      assert {:ok, %{kvs: [%{key: "foo", value: "baz"}]}} =
               EtcdEx.get(conn, "foo", revision: revision + 1)
    end
  end

  describe "put" do
    test "using single key-value", %{conn: conn} do
      {:ok, _} = EtcdEx.put(conn, "foo", "bar")

      {resp, 0} = etcdctl(["get", "foo"])
      assert ["foo", "bar"] == String.split(resp, "\n", trim: true)
    end

    test "touching value", %{conn: conn} do
      {:ok, %{header: %{revision: revision1}}} = EtcdEx.put(conn, "foo", "bar")
      {:ok, %{header: %{revision: revision2}}} = EtcdEx.put(conn, "foo", "", ignore_value: true)

      assert revision2 > revision1
    end

    test "getting previous kv", %{conn: conn} do
      {:ok, _} = EtcdEx.put(conn, "foo", "bar")

      assert {:ok, %{prev_kv: %{key: "foo", value: "bar"}}} =
               EtcdEx.put(conn, "foo", "baz", prev_kv: true)
    end

    test "with lease", %{conn: conn} do
      assert {:error, {:grpc_error, %{grpc_status: 3}}} =
               EtcdEx.put(conn, "foo", "bar", ignore_lease: true)

      {:ok, %{ID: lease}} = EtcdEx.grant(conn, 300)

      # if we don't pass a lease, it is erased
      {:ok, _} = EtcdEx.put(conn, "foo", "bar", lease: lease)
      {:ok, _} = EtcdEx.put(conn, "foo", "baz")
      assert {:ok, %{kvs: [%{lease: 0}]}} = EtcdEx.get(conn, "foo")

      # if we ignore the lease, it is maintained
      {:ok, _} = EtcdEx.put(conn, "foo", "bar", lease: lease)
      {:ok, _} = EtcdEx.put(conn, "foo", "baz", ignore_lease: true)
      assert {:ok, %{kvs: [%{lease: ^lease}]}} = EtcdEx.get(conn, "foo")
    end
  end

  describe "delete" do
    test "simple", %{conn: conn} do
      {_, 0} = etcdctl(["put", "foo", "bar"])

      {:ok, %{deleted: 1}} = EtcdEx.delete(conn, "foo")

      {resp, 0} = etcdctl(["get", "foo"])
      assert [] == String.split(resp, "\n", trim: true)
    end

    test "non-existing key", %{conn: conn} do
      assert {:ok, %{deleted: 0}} = EtcdEx.delete(conn, "foo")
    end

    test "with previous key", %{conn: conn} do
      {_, 0} = etcdctl(["put", "foo", "bar"])

      assert {:ok, %{deleted: 1, prev_kvs: [%{key: "foo", value: "bar"}]}} =
               EtcdEx.delete(conn, "foo", prev_kv: true)
    end

    test "with prefix", %{conn: conn} do
      for {key, value} <- [
            {"kex", "0"},
            {"key1", "1"},
            {"key2", "2"},
            {"kez", "3"}
          ] do
        {_, 0} = etcdctl(["put", key, value])
      end

      assert {:ok, %{deleted: 2}} = EtcdEx.delete(conn, "key", prefix: true)
      assert {:ok, %{kvs: []}} = EtcdEx.get(conn, "key1")
      assert {:ok, %{kvs: []}} = EtcdEx.get(conn, "key2")
      assert {:ok, %{kvs: [%{key: "kez", value: "3"}]}} = EtcdEx.get(conn, "kez")
    end

    test "from key", %{conn: conn} do
      for {key, value} <- [
            {"kex", "0"},
            {"key1", "1"},
            {"key2", "2"},
            {"kez", "3"}
          ] do
        {_, 0} = etcdctl(["put", key, value])
      end

      assert {:ok, %{deleted: 3}} = EtcdEx.delete(conn, "key", from_key: true)
      assert {:ok, %{kvs: []}} = EtcdEx.get(conn, "key1")
      assert {:ok, %{kvs: []}} = EtcdEx.get(conn, "key2")
      assert {:ok, %{kvs: []}} = EtcdEx.get(conn, "kez")
    end
  end

  describe "watch" do
    test "put", %{conn: conn} do
      assert :ok = EtcdEx.watch(conn, self(), "foo")

      {_, 0} = etcdctl(["put", "foo", "bar"])

      assert_receive {:etcd_watch_created, ref} when is_reference(ref)

      assert_receive {:etcd_watch_notify, _ref,
                      %{events: [%{type: :PUT, kv: %{key: "foo", value: "bar"}}]}}
    end

    test "delete", %{conn: conn} do
      {_, 0} = etcdctl(["put", "foo", "bar"])

      assert :ok = EtcdEx.watch(conn, self(), "foo")
      assert [_] = EtcdEx.list_watches(conn, self())

      {_, 0} = etcdctl(["del", "foo"])

      assert_receive {:etcd_watch_created, ref} when is_reference(ref)

      assert_receive {:etcd_watch_notify, _ref,
                      %{events: [%{type: :DELETE, kv: %{key: "foo", value: ""}}]}}
    end

    test "compressed key", %{conn: conn} do
      for {key, value} <- [
            {"foo", "0"},
            {"foo", "1"},
            {"foo", "2"}
          ] do
        {_, 0} = etcdctl(["put", key, value])
      end

      assert {"compacted revision" <> _, 0} = etcdctl(["compact", "2"])

      assert :ok = EtcdEx.watch(conn, self(), "foo", start_revision: 1)
      assert [_] = EtcdEx.list_watches(conn, self())

      assert_receive {:etcd_watch_created, ref} when is_reference(ref)

      assert_receive {:etcd_watch_canceled, _ref, {:compacted, _}}
    end

    test "cancel", %{conn: conn} do
      assert :ok = EtcdEx.watch(conn, self(), "foo")
      assert :ok = EtcdEx.cancel_watch(conn, self())
      assert [] = EtcdEx.list_watches(conn, self())

      {_, 0} = etcdctl(["put", "foo", "bar"])

      refute_receive {:etcd_watch_created, _ref}

      refute_receive {:etcd_watch_notify, _ref, _response}
    end

    test "watch watching process exits", %{conn: conn} do
      task = Task.async(fn ->
        :ok = EtcdEx.watch(conn, self(), "foo")

        {_, 0} = etcdctl(["put", "foo", "bar"])

        self()
      end)

      pid = Task.await(task)

      assert [] = EtcdEx.list_watches(conn, pid)
    end
  end
end

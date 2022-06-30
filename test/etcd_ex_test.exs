defmodule EtcdExTest do
  use EtcdCase, async: false
  use ExUnitProperties

  setup %{etcdctl_path: etcdctl_path} do
    # Make sure etcd is totally empty
    System.cmd(etcdctl_path, ["del", "", "--prefix"])

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
      test "get #{inspect(get_params)} for kvs #{inspect(kvs)}", %{
        conn: conn,
        etcdctl_path: etcdctl_path,
        params: params
      } do
        {kvs, get_params, expected} = params

        for {key, value} <- kvs do
          {_, 0} = System.cmd(etcdctl_path, ["put", key, value])
        end

        {:ok, %{kvs: kvs}} = apply(EtcdEx, :get, [conn] ++ get_params)

        assert expected == Enum.map(kvs, &{&1.key, &1.value})
      end
    end

    @tag timeout: :infinity
    test "get count", %{conn: conn, etcdctl_path: etcdctl_path} do
      key_value_generator = map_of(string(?a..?z, min_length: 1), string(?a..?z, min_length: 1))

      check all(kvs <- key_value_generator, max_runs: 20) do
        for {key, value} <- kvs do
          {_, 0} = System.cmd(etcdctl_path, ["put", key, value])
        end

        {:ok, %{count: count}} = EtcdEx.get(conn, <<0>>, from_key: true, count_only: true)
        assert count == Enum.count(kvs)

        System.cmd(etcdctl_path, ["del", "", "--from-key"])
      end
    end

    test "get previous kv", %{conn: conn, etcdctl_path: etcdctl_path} do
      {_, 0} = System.cmd(etcdctl_path, ["put", "foo", "bar"])
      {:ok, %{header: %{revision: revision}}} = EtcdEx.get(conn, "foo")
      {_, 0} = System.cmd(etcdctl_path, ["put", "foo", "baz"])

      assert {:ok, %{kvs: [%{key: "foo", value: "bar"}]}} = EtcdEx.get(conn, "foo", revision: revision)
      assert {:ok, %{kvs: [%{key: "foo", value: "baz"}]}} = EtcdEx.get(conn, "foo", revision: revision + 1)
    end
  end

  describe "put" do
    test "touch value", %{conn: conn, etcdctl_path: etcdctl_path} do
      {:ok, _} = EtcdEx.put(conn, "foo", "bar")

      {resp, 0} = System.cmd(etcdctl_path, ["get", "foo"])
      assert ["foo", "bar"] == String.split(resp, "\n", trim: true)
    end
  end

  test "delete value", %{conn: conn, etcdctl_path: etcdctl_path} do
    {_, 0} = System.cmd(etcdctl_path, ["put", "foo", "bar"])

    {:ok, _} = EtcdEx.delete(conn, "foo")

    {resp, 0} = System.cmd(etcdctl_path, ["get", "foo"])
    assert [] == String.split(resp, "\n", trim: true)
  end
end

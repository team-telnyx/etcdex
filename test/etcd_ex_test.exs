defmodule EtcdExTest do
  use EtcdCase, async: false

  setup %{etcdctl_path: etcdctl_path} do
    # Make sure etcd is totally empty
    System.cmd(etcdctl_path, ["del", "", "--prefix"])

    {:ok, conn: start_supervised!(EtcdEx)}
  end

  describe "get" do
  for {scenario, get_params, expected} <- [
        {
          [
            {"foo", "bar"}
          ],
          ["foo"],
          [
            {"foo", "bar"}
          ]
        },
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
    @tag params: {scenario, get_params, expected}
    test "get #{inspect(get_params)} for scenario #{inspect(scenario)}", %{
      conn: conn,
      etcdctl_path: etcdctl_path,
      params: params
    } do
      {scenario, get_params, expected} = params

      for {key, value} <- scenario do
        {_, 0} = System.cmd(etcdctl_path, ["put", key, value])
      end

      {:ok, %{kvs: kvs}} = apply(EtcdEx, :get, [conn] ++ get_params)

      assert expected == Enum.map(kvs, &{&1.key, &1.value})
    end
      end
  end

  describe "put" do

  end
  test "put value", %{conn: conn, etcdctl_path: etcdctl_path} do
    {:ok, _} = EtcdEx.put(conn, "foo", "bar")

    {resp, 0} = System.cmd(etcdctl_path, ["get", "foo"])
    assert ["foo", "bar"] == String.split(resp, "\n", trim: true)
  end

  test "delete value", %{conn: conn, etcdctl_path: etcdctl_path} do
    {_, 0} = System.cmd(etcdctl_path, ["put", "foo", "bar"])

    {:ok, _} = EtcdEx.delete(conn, "foo")

    {resp, 0} = System.cmd(etcdctl_path, ["get", "foo"])
    assert [] == String.split(resp, "\n", trim: true)
  end
end

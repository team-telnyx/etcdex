defmodule EtcdEx.RepoTest do
  use ExUnit.Case
  use EtcdEx.Repo.Mock

  alias EtcdEx.Repo

  import ExUnit.CaptureLog

  defmodule Prefix do
    use Repo, prefix: "/test/data"
  end

  defmodule CustomKeys do
    use Repo, prefix: "/test/data"

    def decode_key(key, prefix) do
      key = String.replace_leading(key, prefix, "")

      case key do
        "/ignored" <> _ -> {:error, :ignore}
        "/bad" <> _ -> {:error, :badkey}
        key -> {:ok, String.split(key, "/", trim: true)}
      end
    end

    def encode_key(key, prefix) do
      Enum.join([prefix | key], "/")
    end

    def decode_value(_key, value) do
      case Jason.decode(value) do
        {:ok, 666} -> {:error, :ignore}
        {:ok, value} -> {:ok, value}
      end
    end
  end

  defmodule PubSub do
    use Repo, prefix: "/test/data", pubsub: :etcd_cache_pubsub
  end

  describe "Cache with prefix" do
    setup do
      mock_repo(Prefix, [
        %{key: "/test/data/foo", value: "1"},
        %{key: "/test/data/bar", value: "2"}
      ])
    end

    test "loads data into cache" do
      assert Prefix.get("/foo") == 1
      assert Prefix.get("/bar") == 2
    end

    test "watches keys and updates cache" do
      assert_received({:etcd_watch, "/test/data", _ref})

      etcd_notify(Prefix, [
        %{type: :PUT, kv: %{key: "/test/data/foo", value: "true"}},
        %{type: :DELETE, kv: %{key: "/test/data/bar"}},
        %{type: :PUT, kv: %{key: "/test/data/abc", value: "\"string\""}}
      ])

      assert Prefix.get("/foo") == true
      assert Prefix.get("/bar") == nil
      assert Prefix.get("/abc") == "string"
    end

    test "ignores badly formatted values" do
      log =
        capture_log(fn ->
          etcd_notify(Prefix, [
            %{type: :PUT, kv: %{key: "/test/data/ignored/foo", value: "bad"}}
          ])
        end)

      assert Prefix.get(["ignored", "foo"]) == nil

      assert log =~ "failed to decode value for key /test/data/ignored/foo"
    end

    test "puts data into etcd" do
      Prefix.put("/xyz", %{foo: "bar"})

      assert_received({:etcd_put, "/test/data/xyz", "{\"foo\":\"bar\"}", []})

      Prefix.put("/xyz", %{foo: "baz"}, lease: 1234)

      assert_received({:etcd_put, "/test/data/xyz", "{\"foo\":\"baz\"}", [lease: 1234]})
    end

    test "deletes data from etcd" do
      Prefix.delete("/foo")

      assert_received({:etcd_delete, "/test/data/foo"})
    end
  end

  describe "Cache with custom keys" do
    setup do
      mock_repo(CustomKeys, [
        %{key: "/test/data/a/b", value: "1"},
        %{key: "/test/data/c/d", value: "2"}
      ])
    end

    test "loads data into cache" do
      assert CustomKeys.get(["a", "b"]) == 1
      assert CustomKeys.get(["c", "d"]) == 2
    end

    test "watches keys and updates cache" do
      assert_received({:etcd_watch, "/test/data", _ref})

      etcd_notify(CustomKeys, [
        %{type: :PUT, kv: %{key: "/test/data/a/b", value: "true"}},
        %{type: :DELETE, kv: %{key: "/test/data/c/d"}},
        %{type: :PUT, kv: %{key: "/test/data/foo", value: "\"string\""}}
      ])

      assert CustomKeys.get(["a", "b"]) == true
      assert CustomKeys.get(["c", "d"]) == nil
      assert CustomKeys.get(["foo"]) == "string"
    end

    test "quietly ignores keys that are marked as ignored" do
      log =
        capture_log(fn ->
          etcd_notify(CustomKeys, [
            %{type: :PUT, kv: %{key: "/test/data/ignored/foo", value: "3"}},
            %{type: :PUT, kv: %{key: "/test/data/ignored", value: "4"}}
          ])
        end)

      assert CustomKeys.get(["ignored", "foo"]) == nil
      assert CustomKeys.get(["ignored"]) == nil

      refute log =~ "failed to decode key /test/data/ignored/foo"
      refute log =~ "failed to decode key /test/data/ignored"
    end

    test "ignores and logs keys that fail to decode" do
      log =
        capture_log(fn ->
          etcd_notify(CustomKeys, [
            %{type: :PUT, kv: %{key: "/test/data/bad/foo", value: "3"}},
            %{type: :PUT, kv: %{key: "/test/data/bad", value: "4"}}
          ])
        end)

      assert CustomKeys.get(["bad", "foo"]) == nil
      assert CustomKeys.get(["bad"]) == nil

      assert log =~ "failed to decode key /test/data/bad/foo"
      assert log =~ "failed to decode key /test/data/bad"
    end

    test "ignores badly formatted values" do
      log =
        capture_log(fn ->
          etcd_notify(CustomKeys, [
            %{type: :PUT, kv: %{key: "/test/data/foo", value: "666"}}
          ])
        end)

      assert CustomKeys.get(["foo"]) == nil

      assert log =~ "failed to decode value for key /test/data/foo"
    end

    test "puts data into etcd" do
      CustomKeys.put(["x", "y", "z"], %{foo: "bar"})

      assert_received({:etcd_put, "/test/data/x/y/z", "{\"foo\":\"bar\"}", []})

      CustomKeys.put(["x", "y", "z"], %{foo: "baz"}, lease: 1234)

      assert_received({:etcd_put, "/test/data/x/y/z", "{\"foo\":\"baz\"}", [lease: 1234]})
    end

    test "deletes data from etcd" do
      CustomKeys.delete(["a", "b"])

      assert_received({:etcd_delete, "/test/data/a/b"})
    end
  end

  describe "Cache with pubsub" do
    setup do
      start_supervised!({Phoenix.PubSub, name: :etcd_cache_pubsub})

      mock_repo(PubSub, [
        %{key: "/test/data/foo", value: "1"},
        %{key: "/test/data/bar", value: "2"}
      ])
    end

    test "broadcasts updates for all keys to subscribers" do
      :ok = PubSub.subscribe()

      etcd_notify(PubSub, [
        %{type: :PUT, kv: %{key: "/test/data/foo", value: "3"}},
        %{type: :DELETE, kv: %{key: "/test/data/bar"}}
      ])

      assert_received({:PUT, "/foo", 3})
      assert_received({:DELETE, "/bar"})

      :ok = PubSub.unsubscribe()

      etcd_notify(PubSub, [
        %{type: :PUT, kv: %{key: "/test/data/foo", value: "4"}}
      ])

      refute_received({:PUT, "/foo", _})
    end

    test "broadcasts updates for single key to subscribers" do
      :ok = PubSub.subscribe("/foo")

      etcd_notify(PubSub, [
        %{type: :PUT, kv: %{key: "/test/data/foo", value: "3"}},
        %{type: :DELETE, kv: %{key: "/test/data/bar"}}
      ])

      assert_received({:PUT, "/foo", 3})
      refute_received({:DELETE, "/bar"})

      :ok = PubSub.unsubscribe("/foo")

      etcd_notify(PubSub, [
        %{type: :PUT, kv: %{key: "/test/data/foo", value: "4"}}
      ])

      refute_received({:PUT, "/foo", _})
    end
  end
end

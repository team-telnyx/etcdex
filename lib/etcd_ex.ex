defmodule EtcdEx do
  @moduledoc """
  This module provides interface to Etcd.
  """

  @type conn :: EtcdEx.Connection.t()
  @type key :: String.t()
  @type value :: String.t()
  @type range_end :: String.t()
  @type lease :: integer
  @type limit :: non_neg_integer
  @type revision :: pos_integer
  @type sort :: {sort_target, sort_order}
  @type sort_target :: :KEY | :VERSION | :VALUE | :CREATE | :MOD
  @type sort_order :: :NONE | :ASCEND | :DESCEND
  @type watch :: pid
  @type watch_id :: pos_integer

  @type filters :: [filter]
  @type filter :: :NOPUT | :NODELETE

  @type get_opts :: [get_opt]
  @type get_opt ::
          {:range_end, range_end}
          | {:prefix, boolean}
          | {:from_key, boolean}
          | {:limit, limit}
          | {:revision, revision}
          | {:sort, sort}
          | {:serializable, boolean}
          | {:keys_only, boolean}
          | {:count_only, boolean}
          | {:min_mod_revision, revision}
          | {:max_mod_revision, revision}
          | {:min_create_revision, revision}
          | {:max_create_revision, revision}
          | {:timeout, timeout}

  @type put_opts :: [put_opt]
  @type put_opt ::
          {:lease, lease}
          | {:prev_kv, boolean}
          | {:ignore_value, boolean}
          | {:ignore_lease, boolean}
          | {:timeout, timeout}

  @type delete_opts :: [delete_opt]
  @type delete_opt ::
          {:range_end, range_end}
          | {:prefix, boolean}
          | {:from_key, boolean}
          | {:prev_kv, boolean}
          | {:timeout, timeout}

  @type watch_opts :: [watch_opt]
  @type watch_opt ::
          {:range_end, range_end}
          | {:prefix, boolean}
          | {:from_key, boolean}
          | {:start_revision, revision}
          | {:filters, filters}
          | {:prev_kv, boolean}
          | {:progress_notify, boolean}

  defdelegate child_spec(init_opts), to: EtcdEx.Connection
  defdelegate start_link(start_opts), to: EtcdEx.Connection

  @doc """
  Gets one or range of key-value pairs from Etcd.
  """
  def get(conn, key, opts \\ []) when is_atom(conn) and is_binary(key) and is_list(opts) do
    request =
      conn
      |> :eetcd_kv.new()
      |> :eetcd_kv.with_key(key)
      |> build_get_opts(opts)

    EtcdEx.Connection.get(conn, request)
  end

  defp build_get_opts(req, []), do: req

  defp build_get_opts(req, [{:range_end, range_end} | opts]) do
    req
    |> :eetcd_kv.with_range_end(range_end)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:prefix, true} | opts]) do
    req
    |> :eetcd_kv.with_prefix()
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:prefix, _} | opts]), do: build_get_opts(req, opts)

  defp build_get_opts(req, [{:from_key, true} | opts]) do
    req
    |> :eetcd_kv.with_from_key()
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:from_key, _} | opts]), do: build_get_opts(req, opts)

  defp build_get_opts(req, [{:limit, limit} | opts]) do
    req
    |> :eetcd_kv.with_limit(limit)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:lease, lease} | opts]) do
    req
    |> :eetcd_kv.with_lease(lease)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:revision, revision} | opts]) do
    req
    |> :eetcd_kv.with_rev(revision)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:sort, {sort_target, sort_order}} | opts]) do
    req
    |> :eetcd_kv.with_sort(sort_target, sort_order)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:serializable, true} | opts]) do
    req
    |> :eetcd_kv.with_serializable()
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:serializable, _} | opts]), do: build_get_opts(req, opts)

  defp build_get_opts(req, [{:keys_only, true} | opts]) do
    req
    |> :eetcd_kv.with_keys_only()
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:keys_only, _} | opts]), do: build_get_opts(req, opts)

  defp build_get_opts(req, [{:count_only, true} | opts]) do
    req
    |> :eetcd_kv.with_count_only()
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:count_only, _} | opts]), do: build_get_opts(req, opts)

  defp build_get_opts(req, [{:min_mod_revision, revision} | opts]) do
    req
    |> :eetcd_kv.with_min_mod_rev(revision)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:max_mod_revision, revision} | opts]) do
    req
    |> :eetcd_kv.with_max_mod_rev(revision)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:min_create_revision, revision} | opts]) do
    req
    |> :eetcd_kv.with_min_create_rev(revision)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:max_create_revision, revision} | opts]) do
    req
    |> :eetcd_kv.with_max_create_rev(revision)
    |> build_get_opts(opts)
  end

  defp build_get_opts(req, [{:timeout, timeout} | opts]) do
    req
    |> :eetcd_kv.with_timeout(timeout)
    |> build_get_opts(opts)
  end

  @doc """
  Puts a key-value pair to Etcd.
  """
  @spec put(conn, key, value, put_opts) :: {:ok, any} | {:error, any}
  def put(conn, key, value, opts \\ [])
      when is_atom(conn) and is_binary(key) and is_binary(value) and is_list(opts) do
    request =
      conn
      |> :eetcd_kv.new()
      |> :eetcd_kv.with_key(key)
      |> :eetcd_kv.with_value(value)
      |> build_put_opts(opts)

    EtcdEx.Connection.put(conn, request)
  end

  defp build_put_opts(req, []), do: req

  defp build_put_opts(req, [{:lease, lease} | opts]) do
    req
    |> :eetcd_kv.with_lease(lease)
    |> build_put_opts(opts)
  end

  defp build_put_opts(req, [{:prev_kv, true} | opts]) do
    req
    |> :eetcd_kv.with_prev_kv()
    |> build_put_opts(opts)
  end

  defp build_put_opts(req, [{:prev_kv, _} | opts]), do: build_put_opts(req, opts)

  defp build_put_opts(req, [{:ignore_value, true} | opts]) do
    req
    |> :eetcd_kv.with_ignore_value()
    |> build_put_opts(opts)
  end

  defp build_put_opts(req, [{:ignore_value, _} | opts]), do: build_put_opts(req, opts)

  defp build_put_opts(req, [{:ignore_lease, true} | opts]) do
    req
    |> :eetcd_kv.with_ignore_lease()
    |> build_put_opts(opts)
  end

  defp build_put_opts(req, [{:ignore_lease, _} | opts]), do: build_put_opts(req, opts)

  defp build_put_opts(req, [{:timeout, timeout} | opts]) do
    req
    |> :eetcd_kv.with_timeout(timeout)
    |> build_get_opts(opts)
  end

  @doc """
  Deletes a key-value pair from Etcd.
  """
  @spec delete(conn, key, delete_opts) :: {:ok, any} | {:error, any}
  def delete(conn, key, opts \\ []) do
    request =
      conn
      |> :eetcd_kv.new()
      |> :eetcd_kv.with_key(key)
      |> build_delete_opts(opts)

    EtcdEx.Connection.delete(conn, request)
  end

  defp build_delete_opts(req, []), do: req

  defp build_delete_opts(req, [{:range_end, range_end} | opts]) do
    req
    |> :eetcd_kv.with_range_end(range_end)
    |> build_delete_opts(opts)
  end

  defp build_delete_opts(req, [{:prefix, true} | opts]) do
    req
    |> :eetcd_kv.with_prefix()
    |> build_delete_opts(opts)
  end

  defp build_delete_opts(req, [{:prefix, _} | opts]), do: build_delete_opts(req, opts)

  defp build_delete_opts(req, [{:from_key, true} | opts]) do
    req
    |> :eetcd_kv.with_from_key()
    |> build_delete_opts(opts)
  end

  defp build_delete_opts(req, [{:from_key, _} | opts]), do: build_delete_opts(req, opts)

  defp build_delete_opts(req, [{:prev_kv, true} | opts]) do
    req
    |> :eetcd_kv.with_prev_kv()
    |> build_delete_opts(opts)
  end

  defp build_delete_opts(req, [{:prev_kv, _} | opts]), do: build_delete_opts(req, opts)

  defp build_delete_opts(req, [{:timeout, timeout} | opts]) do
    req
    |> :eetcd_kv.with_timeout(timeout)
    |> build_get_opts(opts)
  end

  @doc """
  Watches operations made on Etcd keys.
  """
  @spec watch(conn, key, watch_opts) :: {:ok, watch, watch_id} | {:error, any}
  def watch(conn, key, opts \\ []) do
    request =
      :eetcd_watch.new()
      |> :eetcd_watch.with_key(key)
      |> build_watch_opts(opts)

    {:ok, watch} = EtcdEx.Watch.start_link({self(), conn})

    case EtcdEx.Watch.watch(watch, request) do
      {:ok, watch_id} ->
        {:ok, watch, watch_id}

      error ->
        EtcdEx.Watch.cancel(watch)

        error
    end
  end

  defp build_watch_opts(req, []), do: req

  defp build_watch_opts(req, [{:range_end, range_end} | opts]) do
    req
    |> :eetcd_watch.with_range_end(range_end)
    |> build_watch_opts(opts)
  end

  defp build_watch_opts(req, [{:prefix, true} | opts]) do
    req
    |> :eetcd_watch.with_prefix()
    |> build_watch_opts(opts)
  end

  defp build_watch_opts(req, [{:prefix, _} | opts]), do: build_watch_opts(req, opts)

  defp build_watch_opts(req, [{:from_key, true} | opts]) do
    req
    |> :eetcd_watch.with_from_key()
    |> build_watch_opts(opts)
  end

  defp build_watch_opts(req, [{:from_key, _} | opts]), do: build_watch_opts(req, opts)

  defp build_watch_opts(req, [{:start_revision, revision} | opts]) do
    req
    |> :eetcd_watch.with_start_revision(revision)
    |> build_watch_opts(opts)
  end

  defp build_watch_opts(req, [{:filters, filters} | opts]) do
    req =
      Enum.reduce(filters, req, fn
        :NOPUT, req -> :eetcd_watch.with_filter_put(req)
        :NODELETE, req -> :eetcd_watch.with_filter_delete(req)
      end)

    build_watch_opts(req, opts)
  end

  defp build_watch_opts(req, [{:prev_kv, true} | opts]) do
    req
    |> :eetcd_watch.with_prev_kv()
    |> build_watch_opts(opts)
  end

  defp build_watch_opts(req, [{:prev_kv, _} | opts]), do: build_watch_opts(req, opts)

  defp build_watch_opts(req, [{:progress_notify, true} | opts]) do
    req
    |> :eetcd_watch.with_progress_notify()
    |> build_watch_opts(opts)
  end

  defp build_watch_opts(req, [{:progress_notify, _} | opts]), do: build_watch_opts(req, opts)

  @doc """
  Reuses an existing watch to observe further keys.
  """
  @spec reuse_watch(watch, key, watch_opts) :: {:ok, watch_id} | {:error, any}
  def reuse_watch(watch, key, opts \\ []) when is_pid(watch) do
    request =
      :eetcd_watch.new()
      |> :eetcd_watch.with_key(key)
      |> build_watch_opts(opts)

    EtcdEx.Watch.watch(watch, request)
  end

  @doc """
  Cancels an Etcd watch.
  """
  @spec cancel_watch(watch) :: :ok
  def cancel_watch(watch) when is_pid(watch) do
    EtcdEx.Watch.cancel(watch)
  end
end
defmodule EtcdEx.Mint do
  @moduledoc """
  This module provides interface to Etcd cluster on top of `Mint`.
  """

  alias EtcdEx.Types

  @opaque t() :: %__MODULE__{}

  defstruct [:conn, streams: %{}]

  @doc """
  Wraps a `Mint` connection.
  """
  @spec wrap(Mint.HTTP2.t()) :: t
  def wrap(conn), do: %__MODULE__{conn: conn}

  @doc """
  Unwraps a `EtcdEx.Mint` connection.
  """
  @spec unwrap(t) :: Mint.HTTP.t()
  def unwrap(%__MODULE__{conn: conn}), do: conn

  @doc """
  Retrieve range of key-value pairs from Etcd.
  """
  @spec get(t, Types.key(), [Types.get_opt()]) ::
          {:ok, t, Mint.Types.request_ref()} | {:error, t, Mint.Types.error()}
  def get(env, key, opts \\ []) when is_binary(key) and is_list(opts) do
    body =
      EtcdEx.Proto.RangeRequest
      |> struct([key: key] ++ build_get_opts(key, opts))
      |> EtcdEx.Proto.RangeRequest.encode()

    send(env, "/etcdserverpb.KV/Range", body, EtcdEx.Proto.RangeResponse)
  end

  defp build_get_opts(_key, []), do: []

  defp build_get_opts(key, [{:range_end, range_end} | opts]),
    do: [{:range_end, range_end} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:prefix, true} | opts]),
    do: [{:range_end, next_key(key)} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:prefix, _} | opts]),
    do: build_get_opts(key, opts)

  defp build_get_opts(key, [{:from_key, true} | opts]),
    do: [{:range_end, <<0>>} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:from_key, _} | opts]),
    do: build_get_opts(key, opts)

  defp build_get_opts(key, [{:limit, limit} | opts]),
    do: [{:limit, limit} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:lease, lease} | opts]),
    do: [{:lease, lease} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:revision, revision} | opts]),
    do: [{:revision, revision} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:sort, {sort_target, sort_order}} | opts]),
    do: [{:sort_target, sort_target}, {:sort_order, sort_order} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:serializable, true} | opts]),
    do: [{:serializable, true} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:serializable, _} | opts]),
    do: build_get_opts(key, opts)

  defp build_get_opts(key, [{:keys_only, true} | opts]),
    do: [{:keys_only, true} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:keys_only, _} | opts]),
    do: build_get_opts(key, opts)

  defp build_get_opts(key, [{:count_only, true} | opts]),
    do: [{:count_only, true} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:count_only, _} | opts]),
    do: build_get_opts(key, opts)

  defp build_get_opts(key, [{:min_mod_revision, revision} | opts]),
    do: [{:min_mod_revision, revision} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:max_mod_revision, revision} | opts]),
    do: [{:max_mod_revision, revision} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:min_create_revision, revision} | opts]),
    do: [{:min_create_revision, revision} | build_get_opts(key, opts)]

  defp build_get_opts(key, [{:max_create_revision, revision} | opts]),
    do: [{:max_create_revision, revision} | build_get_opts(key, opts)]

  def next_key(key) do
    key
    |> :binary.bin_to_list()
    |> Enum.reverse()
    |> case do
      [] ->
        <<0>>

      [0xFF] ->
        # This is not really a practical case, as the key is "\xff",
        # which means it cannot be a prefix. In this case the search
        # interval will be ['\xff', '\xff'), which results in ø.
        key

      [0xFF, c | rest] ->
        [c + 1 | rest]
        |> Enum.reverse()
        |> :binary.list_to_bin()

      [c | rest] ->
        [c + 1 | rest]
        |> Enum.reverse()
        |> :binary.list_to_bin()
    end
  end

  defp send(env, path, body, response_decoder) do
    %{conn: conn} = env

    len = byte_size(body)
    data = <<0, len::32, body::binary>>

    headers = [
      {"grpc-encoding", "identity"},
      {"content-type", "application/grpc+proto"}
    ]

    with {:ok, conn, request_ref} <- Mint.HTTP.request(conn, "POST", path, headers, :stream),
         {:ok, conn} <- Mint.HTTP.stream_request_body(conn, request_ref, data),
         {:ok, conn} <- Mint.HTTP.stream_request_body(conn, request_ref, :eof) do
      streams = Map.put(env.streams, request_ref, {response_decoder, ""})
      env = %{env | conn: conn, streams: streams}

      {:ok, env, request_ref}
    else
      {:error, conn, reason} -> {:error, %{env | conn: conn}, reason}
    end
  end

  @doc """
  Streams the next batch of responses from the given message.
  """
  @spec stream(t, term) ::
          {:ok, t, [Types.response()]}
          | {:error, t, Mint.Types.error(), [Types.response()]}
          | :unknown
  def stream(env, message) do
    case Mint.HTTP.stream(env.conn, message) do
      {:ok, conn, responses} ->
        {responses, env} = Enum.reduce(responses, {[], env}, &reduce_responses/2)

        {:ok, %{env | conn: conn}, responses}

      {:error, conn, reason, responses} ->
        {responses, env} = Enum.reduce(responses, {[], env}, &reduce_responses/2)

        {:error, %{env | conn: conn}, reason, responses}

      :unknown ->
        :unknown
    end
  end

  @doc false
  def cancel_request(env, request_ref) do
    %{conn: conn, streams: streams} = env

    case Mint.HTTP2.cancel_request(conn, request_ref) do
      {:ok, conn} ->
        {:ok, %{env | conn: conn, streams: Map.delete(streams, request_ref)}}

      {:error, conn, reason} ->
        {:error, %{env | conn: conn}, reason}
    end
  end

  defp reduce_responses({:data, request_ref, data}, {responses, env}) do
    {decoder, pending} = Map.fetch!(env.streams, request_ref)

    case pending <> data do
      <<0, len::32, encoded::binary-size(len), rest::binary>> ->
        streams = Map.put(env.streams, request_ref, {decoder, rest})
        env = %{env | streams: streams}
        {responses ++ [{:data, request_ref, sanitize_response(decoder.decode(encoded))}], env}

      new_pending ->
        streams = Map.put(env.streams, request_ref, {decoder, new_pending})
        {responses, %{env | streams: streams}}
    end
  end

  defp reduce_responses({:done, request_ref}, {responses, env}) do
    {responses ++ [{:done, request_ref}], %{env | streams: Map.delete(env.streams, request_ref)}}
  end

  defp reduce_responses(other, {responses, env}) do
    {responses ++ [other], env}
  end

  defp sanitize_response(%_{} = pb_response) do
    pb_response
    |> Map.from_struct()
    |> Enum.reject(&match?({:__unknown_fields__, _}, &1))
    |> Enum.map(fn
      {key, %_{} = pb_response} -> {key, sanitize_response(pb_response)}
      {key, list} when is_list(list) -> {key, Enum.map(list, &sanitize_response/1)}
      other -> other
    end)
    |> Map.new()
  end

  defp sanitize_response(other), do: other

  @doc """
  Put key-value pair into Etcd.
  """
  @spec put(t, Types.key(), Types.value(), [Types.put_opt()]) ::
          {:ok, t} | {:error, t, Mint.Types.error()}
  def put(env, key, value, opts \\ [])
      when is_binary(key) and is_binary(value) and is_list(opts) do
    body =
      EtcdEx.Proto.PutRequest
      |> struct([key: key, value: value] ++ build_put_opts(key, opts))
      |> EtcdEx.Proto.PutRequest.encode()

    send(env, "/etcdserverpb.KV/Put", body, EtcdEx.Proto.PutResponse)
  end

  defp build_put_opts(_key, []), do: []

  defp build_put_opts(key, [{:lease, lease} | opts]),
    do: [{:lease, lease} | build_put_opts(key, opts)]

  defp build_put_opts(key, [{:prev_kv, true} | opts]),
    do: [{:prev_kv, true} | build_put_opts(key, opts)]

  defp build_put_opts(key, [{:prev_kv, _} | opts]),
    do: build_put_opts(key, opts)

  defp build_put_opts(key, [{:ignore_value, true} | opts]),
    do: [{:ignore_value, true} | build_put_opts(key, opts)]

  defp build_put_opts(key, [{:ignore_value, _} | opts]),
    do: build_put_opts(key, opts)

  defp build_put_opts(key, [{:ignore_lease, true} | opts]),
    do: [{:ignore_lease, true} | build_put_opts(key, opts)]

  defp build_put_opts(key, [{:ignore_lease, _} | opts]),
    do: build_put_opts(key, opts)

  @doc """
  Delete key-value pair from Etcd.
  """
  @spec delete(t, Types.key(), [Types.delete_opt()]) :: {:ok, t} | {:error, t, Mint.Types.error()}
  def delete(env, key, opts \\ []) do
    body =
      EtcdEx.Proto.DeleteRangeRequest
      |> struct([key: key] ++ build_delete_opts(key, opts))
      |> EtcdEx.Proto.DeleteRangeRequest.encode()

    send(env, "/etcdserverpb.KV/DeleteRange", body, EtcdEx.Proto.DeleteRangeResponse)
  end

  defp build_delete_opts(_key, []), do: []

  defp build_delete_opts(key, [{:range_end, range_end} | opts]),
    do: [{:range_end, range_end} | build_delete_opts(key, opts)]

  defp build_delete_opts(key, [{:prefix, true} | opts]),
    do: [{:range_end, next_key(key)} | build_delete_opts(key, opts)]

  defp build_delete_opts(key, [{:prefix, _} | opts]),
    do: build_delete_opts(key, opts)

  defp build_delete_opts(key, [{:from_key, true} | opts]),
    do: [{:range_end, <<0>>} | build_delete_opts(key, opts)]

  defp build_delete_opts(key, [{:from_key, _} | opts]),
    do: build_delete_opts(key, opts)

  defp build_delete_opts(key, [{:prev_kv, true} | opts]),
    do: [{:prev_kv, true} | build_delete_opts(key, opts)]

  defp build_delete_opts(key, [{:prev_kv, _} | opts]),
    do: build_delete_opts(key, opts)

  @doc """
  """
  @spec compact(t, Types.revision(), physical? :: boolean) ::
          {:ok, t, Mint.Types.request_ref()} | {:error, t, Mint.Types.error()}
  def compact(env, revision, physical?) do
    body =
      EtcdEx.Proto.CompactionRequest
      |> struct(revision: revision, physical: physical?)
      |> EtcdEx.Proto.CompactionRequest.encode()

    send(env, "/etcdserverpb.KV/Compact", body, EtcdEx.Proto.CompactionResponse)
  end

  @doc """
  """
  @spec grant(t, Types.ttl()) :: {:ok, t} | {:error, t, Mint.Types.error()}
  def grant(env, ttl, lease_id \\ 0) when is_integer(ttl) and ttl >= 0 do
    body =
      EtcdEx.Proto.LeaseGrantRequest
      |> struct(ID: lease_id, TTL: ttl)
      |> EtcdEx.Proto.LeaseGrantRequest.encode()

    send(env, "/etcdserverpb.Lease/LeaseGrant", body, EtcdEx.Proto.LeaseGrantResponse)
  end

  @doc """
  """
  @spec revoke(t, Types.lease_id()) :: {:ok, t} | {:error, t, Mint.Types.error()}
  def revoke(env, lease_id) when is_integer(lease_id) do
    body =
      EtcdEx.Proto.LeaseRevokeRequest
      |> struct(ID: lease_id)
      |> EtcdEx.Proto.LeaseRevokeRequest.encode()

    send(env, "/etcdserverpb.Lease/LeaseRevoke", body, EtcdEx.Proto.LeaseRevokeResponse)
  end

  @doc """
  Renew the lease.
  """
  @spec keep_alive(t, Types.lease_id()) :: {:ok, t} | {:error, t, Mint.Types.error()}
  def keep_alive(env, lease_id) do
    body =
      EtcdEx.Proto.LeaseKeepAliveRequest
      |> struct(ID: lease_id)
      |> EtcdEx.Proto.LeaseKeepAliveRequest.encode()

    send(env, "/etcdserverpb.Lease/LeaseKeepAlive", body, EtcdEx.Proto.LeaseKeepAliveResponse)
  end

  @doc """
  """
  @spec ttl(t, Types.lease_id(), [Types.ttl_opt()]) :: {:ok, t} | {:error, t, Mint.Types.error()}
  def ttl(env, lease_id, opts \\ []) do
    body =
      EtcdEx.Proto.LeaseTimeToLiveRequest
      |> struct([ID: lease_id] ++ build_ttl_opts(opts))
      |> EtcdEx.Proto.LeaseTimeToLiveRequest.encode()

    send(env, "/etcdserverpb.Lease/LeaseTimeToLive", body, EtcdEx.Proto.LeaseTimeToLiveResponse)
  end

  defp build_ttl_opts([]), do: []

  defp build_ttl_opts([{:keys, true} | opts]),
    do: [{:keys, true} | build_ttl_opts(opts)]

  defp build_ttl_opts([{:keys, _} | opts]),
    do: build_ttl_opts(opts)

  @doc """
  """
  @spec leases(t) :: {:ok, t} | {:error, t, Mint.Types.error()}
  def leases(env) do
    body =
      EtcdEx.Proto.LeaseLeasesRequest
      |> struct()
      |> EtcdEx.Proto.LeaseLeasesRequest.encode()

    send(env, "/etcdserverpb.Lease/LeaseLeases", body, EtcdEx.Proto.LeaseLeasesResponse)
  end

  @doc """
  Opens a watch stream.
  """
  @spec open_watch_stream(t) ::
          {:ok, t, Mint.Types.request_ref()} | {:error, t, Mint.Types.error()}
  def open_watch_stream(env) do
    %{conn: conn} = env

    headers = [
      {"grpc-encoding", "identity"},
      {"content-type", "application/grpc+proto"}
    ]

    case Mint.HTTP.request(conn, "POST", "/etcdserverpb.Watch/Watch", headers, :stream) do
      {:ok, conn, request_ref} ->
        streams = Map.put(env.streams, request_ref, {EtcdEx.Proto.WatchResponse, ""})
        {:ok, %{env | conn: conn, streams: streams}, request_ref}

      {:error, conn, reason} ->
        {:error, %{env | conn: conn}, reason}
    end
  end

  @doc """
  """
  @spec close_watch_stream(t, Mint.Types.request_ref()) ::
          {:ok, t} | {:error, t, Mint.Types.error()}
  def close_watch_stream(env, request_ref) do
    %{conn: conn} = env

    case Mint.HTTP.stream_request_body(conn, request_ref, :eof) do
      {:ok, conn} -> {:ok, %{env | conn: conn}}
      {:error, conn, reason} -> {:error, %{env | conn: conn}, reason}
    end
  end

  @doc """
  """
  @spec watch(t, Mint.Types.request_ref(), Types.key(), [Types.watch_opt()]) ::
          {:ok, t} | {:error, t, Mint.Types.error()}
  def watch(env, request_ref, key, opts \\ []) do
    %{conn: conn} = env

    create_request =
      EtcdEx.Proto.WatchCreateRequest
      |> struct([key: key] ++ build_watch_opts(key, opts))

    body =
      EtcdEx.Proto.WatchRequest
      |> struct(request_union: {:create_request, create_request})
      |> EtcdEx.Proto.WatchRequest.encode()

    len = byte_size(body)
    data = <<0, len::32, body::binary>>

    case Mint.HTTP.stream_request_body(conn, request_ref, data) do
      {:ok, conn} -> {:ok, %{env | conn: conn}}
      {:error, conn, reason} -> {:error, %{env | conn: conn}, reason}
    end
  end

  defp build_watch_opts(_key, []), do: []

  defp build_watch_opts(key, [{:range_end, range_end} | opts]),
    do: [{:range_end, range_end} | build_watch_opts(key, opts)]

  defp build_watch_opts(key, [{:prefix, true} | opts]),
    do: [{:range_end, next_key(key)} | build_watch_opts(key, opts)]

  defp build_watch_opts(key, [{:prefix, _} | opts]),
    do: build_watch_opts(key, opts)

  defp build_watch_opts(key, [{:from_key, true} | opts]),
    do: [{:range_end, <<0>>} | build_watch_opts(key, opts)]

  defp build_watch_opts(key, [{:from_key, _} | opts]),
    do: build_watch_opts(key, opts)

  defp build_watch_opts(key, [{:start_revision, revision} | opts]),
    do: [{:start_revision, revision} | build_watch_opts(key, opts)]

  defp build_watch_opts(key, [{:filters, filters} | opts]),
    do: [{:filters, filters} | build_watch_opts(key, opts)]

  defp build_watch_opts(key, [{:prev_kv, true} | opts]),
    do: [{:prev_kv, true} | build_watch_opts(key, opts)]

  defp build_watch_opts(key, [{:prev_kv, _} | opts]),
    do: build_watch_opts(key, opts)

  defp build_watch_opts(key, [{:progress_notify, true} | opts]),
    do: [{:progress_notify, true} | build_watch_opts(key, opts)]

  defp build_watch_opts(req, [{:progress_notify, _} | opts]),
    do: build_watch_opts(req, opts)

  @doc """
  """
  @spec cancel_watch(t, Mint.Types.request_ref(), Types.watch_id()) ::
          {:ok, t} | {:error, t, Mint.Types.error()}
  def cancel_watch(env, request_ref, watch_id) do
    %{conn: conn} = env

    cancel_request =
      EtcdEx.Proto.WatchCancelRequest
      |> struct(watch_id: watch_id)

    body =
      EtcdEx.Proto.WatchRequest
      |> struct(request_union: {:cancel_request, cancel_request})
      |> EtcdEx.Proto.WatchRequest.encode()

    len = byte_size(body)
    data = <<0, len::32, body::binary>>

    case Mint.HTTP.stream_request_body(conn, request_ref, data) do
      {:ok, conn} -> {:ok, %{env | conn: conn}}
      {:error, conn, reason} -> {:error, %{env | conn: conn}, reason}
    end
  end

  @doc """
  """
  @spec lock(t, Types.name(), Types.lease_id()) ::
          {:ok, t} | {:error, t, Mint.Types.error()}
  def lock(env, name, lease_id) do
    body =
      EtcdEx.Proto.LockRequest
      |> struct(name: name, lease: lease_id)
      |> EtcdEx.Proto.LockRequest.encode()

    send(env, "/v3lockpb.Lock/Lock", body, EtcdEx.Proto.LockResponse)
  end

  @doc """
  """
  @spec unlock(t, Types.key()) ::
          {:ok, t} | {:error, t, Mint.Types.error()}
  def unlock(env, key) do
    body =
      EtcdEx.Proto.UnlockRequest
      |> struct(key: key)
      |> EtcdEx.Proto.UnlockRequest.encode()

    send(env, "/v3lockpb.Lock/Unlock", body, EtcdEx.Proto.UnlockResponse)
  end

  @doc """
  """
  def add_member(env, peer_urls, learner?) do
    body =
      EtcdEx.Proto.MemberAddRequest
      |> struct(peerURLs: peer_urls, isLearner: learner?)
      |> EtcdEx.Proto.MemberAddRequest.encode()

    send(env, "/etcdserverpb.Cluster/MemberAdd", body, EtcdEx.Proto.MemberAddResponse)
  end

  @doc """
  """
  def remove_member(env, member_id) do
    body =
      EtcdEx.Proto.MemberRemoveRequest
      |> struct(ID: member_id)
      |> EtcdEx.Proto.MemberRemoveRequest.encode()

    send(env, "/etcdserverpb.Cluster/MemberRemove", body, EtcdEx.Proto.MemberRemoveResponse)
  end

  @doc """
  """
  def update_member(env, member_id, peer_urls) do
    body =
      EtcdEx.Proto.MemberUpdateRequest
      |> struct(ID: member_id, peerURLs: peer_urls)
      |> EtcdEx.Proto.MemberUpdateRequest.encode()

    send(env, "/etcdserverpb.Cluster/MemberUpdate", body, EtcdEx.Proto.MemberUpdateResponse)
  end

  @doc """
  """
  def list_members(env) do
    body =
      EtcdEx.Proto.MemberListRequest
      |> struct()
      |> EtcdEx.Proto.MemberListRequest.encode()

    send(env, "/etcdserverpb.Cluster/MemberList", body, EtcdEx.Proto.MemberListResponse)
  end

  @doc """
  """
  def promote_member(env, member_id) do
    body =
      EtcdEx.Proto.MemberPromoteRequest
      |> struct(ID: member_id)
      |> EtcdEx.Proto.MemberPromoteRequest.encode()

    send(env, "/etcdserverpb.Cluster/MemberPromote", body, EtcdEx.Proto.MemberPromoteResponse)
  end
end

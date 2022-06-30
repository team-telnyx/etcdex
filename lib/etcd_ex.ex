defmodule EtcdEx do
  @moduledoc """
  This module provides interface to Etcd.
  """

  alias EtcdEx.Types

  @type start_opt ::
          {:options, [option]}
          | {:transport, transport}
          | {:transport_opts, transport_opts}

  @type option ::
          {:mode, :connect_all | :random}
          | {:name, String.t()}
          | {:password, String.t()}
          | {:retry, non_neg_integer}
          | {:retry_timeout, pos_integer}
          | {:connect_timeout, timeout}
          | {:auto_sync_interval_ms, timeout}
          | extended_options

  @type transport :: :tcp | :tls | :ssl

  @type transport_opts :: [:gen_tcp.connect_option()] | [:ssl.connect_option()]

  @type extended_options :: {atom, any}

  @type conn :: EtcdEx.Connection.t()

  @type watch_ref :: reference
  @type watching_process :: pid

  @default_timeout :timer.seconds(5)

  @doc """
  Returns a specification to start `EtcdEx` under a supervisor.
  """
  @spec child_spec([start_opt]) :: Supervisor.child_spec()
  defdelegate child_spec(init_opts), to: EtcdEx.Connection

  @doc """
  Starts the `EtcdEx` client as a worker process.

  Manually it can be started as:

      EtcdEx.start_link(name: MyApp.Etcd)

  In your supervisor tree, you would write:

      Supervisor.start_link([
        {EtcdEx, name: MyApp.Etcd}
      ], strategy: :one_for_one)

  ## Options

  The client requires the following keys:

    * `:name` - the name of the client connection

  The following keys are optional:

    * `:endpoints` - list of host:port endpoints. Defaults to `["localhost:2379"]`.
    * `:options` - general etcd connection options:
      * `:mode` - when set to `:connect_all`, it creates multiple sub-connections
        (one sub-connection per each endpoint) and the balancing policy is round-robin.
        When set to `:random`, only one connection will be opened to a random endpoint,
        and it will be used to send all client requests; the pinned address is maintained
        until the client connection is closed; if the client receives an error, it
        randomly picks another endpoint. Defaults to `:connect_all`.
      * `:name` and `:password` - used to authenticate in etcd.
      * `:connect_timeout` - is the connection timeout. Defaults to one second (1000).
      * `:retry` - is the number of times it will try to reconnect on failure before
        giving up. Defaults to zero (disabled).
      * `:retry_timeout` - is the time between retries in milliseconds.
      * `:auto_sync_interval_ms` - sets the default interval of auto-sync. Default is 0,
        which means no auto-sync. With auto-sync enabled, the cluster member list will
        be automatically synchronized via the MemberList API of etcd, and will try to
        connect any new endpoints if `:mode` is `:connect_all`.
    * `:transport` - one of `:tcp`, `:tls` or `:ssl`. Defaults to `:tcp`.
    * `:transport_opts` - transport-specific settings.
  """
  @spec start_link([start_opt]) :: GenServer.on_start()
  defdelegate start_link(start_opts), to: EtcdEx.Connection

  @doc """
  Gets one or a range of key-value pairs from Etcd.

  The etcd3 data model indexes all keys over a flat binary key space. This differs
  from other key-value store systems that use a hierarchical system of organizing
  keys into directories. Instead of listing keys by directory, keys are listed by
  key intervals `[a, b)`.

  These intervals are often referred to as "ranges" in etcd3. Operations over
  ranges are more powerful than operations on directories. Like a hierarchical
  store, intervals support single key lookups via `[a, a+1)` (e.g., `["a", "a\\x00")`
  looks up `"a"`) and directory lookups by encoding keys by directory depth. In
  addition to those operations, intervals can also encode prefixes; for example the
  interval `["a", "b")` looks up all keys prefixed by the string `"a"`.

  By convention, ranges for a request are denoted by the `key` and `:range_end`
  option. The `key` argument is the first key of the range and should be non-empty.
  The `:range_end` is the key following the last key of the range. If `:range_end`
  is not given or empty, the range is defined to contain only the `key` argument.
  If `:range_end` is key plus one (e.g., `"aa"+1 == "ab"`, `"a\\xff"+1 == "b"`), then
  the range represents all keys prefixed with key. If both `key` and `:range_end`
  are `"\\0"`, then range represents all keys. If `:range_end` is `"\\0"`, the range is
  all keys greater than or equal to the `key` argument.

  ## Options

  The following keys are optional:

    * `:range_end` - the key range to fetch.
    * `:prefix` - if true, sets up `:range_end` as `a+1`.
    * `:from_key` - if true, sets up `:range_end` as `key` to represent all keys after
      `key` argument.
    * `:limit` - the maximum number of keys returned for the request. When limit is set
      to 0 (the default), it is treated as no limit.
    * `:revision` - the point-in-time of the key-value store to use for the range. If
      `:revision` is less or equal to zero, the range is over the latest key-value store.
      If the revision is compacted, ErrCompacted is returned as a response.
    * `:sort` - the key-value field to sort and the ordering for the returned response.
    * `:serializable` - sets the range request to use serializable member-local reads.
      By default, Range is linearizable; it reflects the current consensus of the
      cluster. For better performance and availability, in exchange for possible stale
      reads, a serializable range request is served locally without needing to reach
      consensus with other nodes in the cluster.
    * `:keys_only` - return only the keys and not the values.
    * `:count_only` - return only the count of the keys in the range.
    * `:min_mod_revision` - the lower bound for key mod revisions; filters out lesser
      mod revisions.
    * `:max_mod_revision` - the upper bound for key mod revisions; filters out greater
      mod revisions.
    * `:min_create_revision` - the lower bound for key create revisions; filters out
      lesser create revisions.
    * `:max_create_revision` - the upper bound for key create revisions; filters out
      greater create revisions.
    * `:timeout` - indicates max time to wait for a response. Defaults to `:infinity`.

  ## Response

  The response is formed by a map such as:

      %{
        header: %{
          cluster_id: 16182920199522267672,
          member_id: 5619527364212512701,
          revision: 47077139,
          raft_term: 13
        },
        kvs [
          ...
        ],
        more: false,
        count: 1024
      }

  Details:

    * `:header` - all responses from etcd have an attached response header which
      includes cluster metadata for the response:
      * `:cluster_id` - the ID of the cluster generating the response.
      * `:member_id` - the ID of the member generating the response.
      * `:revision` - the revision of the key-value store when generating the
        response.
    * `:kvs` - the list of key-value pairs matched by the range request. When
      `:count_only` is `true`, `:kvs` is empty.
    * `:more` - indicates if there are more keys to return in the requested range
      if `:limit` is set.
    * `:count` - the total number of keys satisfying the range request.

  ## Key-Value pair

  The key-value pairs under `:kvs` are in the form of:

      %{
        create_revision: 46752355,
        key: "/foo",
        lease: 0,
        mod_revision: 46752355,
        value: "",
        version: 1
      }

    * `:key` - key bytes in binary. An empty key is not allowed.
    * `:value` - value bytes in binary.
    * `:version` - version is the version of the key. A deletion resets the version
      to zero and any modification of the key increases its version.
    * `:create_revision` - revision of the last creation on the key.
    * `:mod_revision` - revision of the last modification on the key.
    * `:lease` - the ID of the lease attached to the key. If lease is 0, then no
      lease is attached to the key.
  """
  @spec get(conn, Types.key(), [Types.get_opt()], timeout) ::
          {:ok, any} | {:error, Mint.Types.error()}
  def get(conn, key, opts \\ [], timeout \\ @default_timeout)
      when is_binary(key) and is_list(opts) do
    EtcdEx.Connection.unary(conn, :get, [key, opts], timeout)
  end

  @doc """
  Puts a key-value pair to Etcd.

  Both arguments `key` and `value` must be binaries.

  ## Options

  `put` accepts the following options:

    * `:lease` - the lease ID to associate with the key in the key-value store.
      A lease value of 0 indicates no lease.
    * `:prev_kv` - when set, responds with the key-value pair data before the update
      from this put call.
    * `:ignore_value` - when set, update the key without changing its current value.
      Returns an error if the key does not exist.
    * `:ignore_lease` - when set, update the key without changing its current lease.
      Returns an error if the key does not exist.
    * `:timeout` - indicates max time to wait for a response. Defaults to `:infinity`.
  """
  @spec put(conn, Types.key(), Types.value(), [Types.put_opt()], timeout) ::
          {:ok, any} | {:error, Mint.Types.error()}
  def put(conn, key, value, opts \\ [], timeout \\ @default_timeout)
      when is_binary(key) and is_binary(value) and is_list(opts) do
    EtcdEx.Connection.unary(conn, :put, [key, value, opts], timeout)
  end

  @doc """
  Deletes key-value pair(s) from Etcd.

  ## Options

  `delete` accepts the following options:

    * `:range_end` - the key range to delete.
    * `:prefix` - if true, sets up `:range_end` as `a+1`.
    * `:from_key` - if true, sets up `:range_end` as `key` to represent all keys after
      `key` argument.
    * `:prev_kv` - when set, return the contents of the deleted key-value pairs.
    * `:timeout` - indicates max time to wait for a response. Defaults to `:infinity`.
  """
  @spec delete(conn, Types.key(), [Types.delete_opt()], timeout) ::
          {:ok, any} | {:error, Mint.Types.error()}
  def delete(conn, key, opts \\ [], timeout \\ @default_timeout) do
    EtcdEx.Connection.unary(conn, :delete, [key, opts], timeout)
  end

  @doc """
  Obtain a lease.

  The argument `ttl` is the advisory time-to-live, in seconds.

  The only option available is `:timeout` which indicates how long to wait for
  a response from the Etcd cluster.

  Leases are a mechanism for detecting client liveness. The cluster grants
  leases with a time-to-live. A lease expires if the etcd cluster does not
  receive a keepAlive within a given TTL period.

  To tie leases into the key-value store, each key may be attached to at most
  one lease. When a lease expires or is revoked, all keys attached to that
  lease will be deleted. Each expired key generates a delete event in the event
  history.

  ## Response

  The response looks like:

      %{
        ID: 4658271320501810998,
        TTL: 300,
        error: "",
        header: %{
          cluster_id: 16182920199522267672,
          member_id: 6198688855164797093,
          raft_term: 13,
          revision: 47427980
        }
      }

    * `:ID` - the lease ID for the granted lease.
    * `:TTL` - is the server selected time-to-live, in seconds, for the lease.
  """
  @spec grant(conn, Types.ttl(), timeout) :: {:ok, any} | {:error, Mint.Types.error()}
  def grant(conn, ttl, timeout \\ @default_timeout) when is_integer(ttl) and ttl >= 0 do
    EtcdEx.Connection.unary(conn, :grant, [ttl], timeout)
  end

  @doc """
  Revokes a previously granted lease.

  The response is of the form:

      %{
        header: %{
          cluster_id: 16182920199522267672,
          member_id: 6198688855164797093,
          raft_term: 13,
          revision: 47452709
        }
      }
  """
  @spec revoke(conn, Types.lease_id(), timeout) ::
          {:ok, any} | {:error, Mint.Types.error()}
  def revoke(conn, lease_id, timeout \\ @default_timeout) do
    EtcdEx.Connection.unary(conn, :revoke, [lease_id], timeout)
  end

  @doc """
  Refreshes an existing lease.

  The `lease_id` should have been obtained from a previous call to `grant/3`.

  ## Response

  The response looks like:

      %{
        ID: 4658271320501810998,
        TTL: 300,
        header: %{
          cluster_id: 16182920199522267672,
          member_id: 6198688855164797093,
          raft_term: 13,
          revision: 47428392
        }
      }

    * `:ID` - the lease that was refreshed with a new TTL.
    * `:TTL` - the new time-to-live, in seconds, that the lease has remaining.
  """
  @spec keep_alive(conn, Types.lease_id(), timeout) ::
          {:ok, any} | {:error, Mint.Types.error()}
  def keep_alive(conn, lease_id, timeout \\ @default_timeout) do
    EtcdEx.Connection.unary(conn, :keep_alive, [lease_id], timeout)
  end

  @doc """
  Checks the advisory time-to-live from a lease.

  The `lease_id` should have been obtained from a previous call to `grant/3`.

  If `with_keys` argument is `true`, the response will have the `:keys` field
  containing a list of all keys associated with the `lease_id`.

  ## Response

  The response looks like:

      %{
        ID: 4658271320501810998,
        TTL: 231,
        grantedTTL: 300,
        header: %{
          cluster_id: 16182920199522267672,
          member_id: 6198688855164797093,
          raft_term: 13,
          revision: 47429656
        },
        keys: []
      }

    * `:ID` - the queried lease ID.
    * `:TTL` - the time-to-live, in seconds, that the lease has remaining.
    * `:grantedTTL` - the time, in seconds, of the time-to-live requested when
      the lease was granted.
    * `:keys` - if `with_keys` is `true`, it will contain a list of keys that
      have been assigned to the lease.
  """
  @spec ttl(conn, Types.lease_id(), [Types.ttl_opt()], timeout) ::
          {:ok, any} | {:error, Mint.Types.error()}
  def ttl(conn, lease_id, opts \\ [], timeout \\ @default_timeout) do
    EtcdEx.Connection.unary(conn, :ttl, [lease_id, opts], timeout)
  end

  @doc """
  List all leases from the Etcd cluster.

  The response is of the form:

      %{
        header: %{
          cluster_id: 16182920199522267672,
          member_id: 6198688855164797093,
          raft_term: 13,
          revision: 47430034
        },
        leases: [
          %{ID: 6322351403492000182},
          %{ID: 4658271320501761384},
          %{ID: 4658271320501772555}
        ]
      }

    * `:leases` - list of leases.
  """
  @spec leases(conn, timeout) :: {:ok, any} | {:error, Mint.Types.error()}
  def leases(conn, timeout \\ @default_timeout) do
    EtcdEx.Connection.unary(conn, :leases, [], timeout)
  end

  @doc """
  Opens a watch stream and watches for changes on keys.

  An etcd3 watch waits for changes to keys by continuously watching from a given
  revision, either current or historical, and streams key updates back to the client.

  On success, the return value has the form `{:ok, watch_stream}`. The `watch_stream` is
  a reference to the created stream, that can be used to cancel/modify the stream at any
  moment.

  Watch streams can be modified by passing different `watch_params` to a previously created
  `watch_stream`. In order to cancel the watch, use `cancel_watch`.

  Watch streams are recreated on reconnections.

  ## Watch streams

  Watches are long-running requests and use gRPC streams to stream event data. A watch
  stream is bi-directional; the client writes to the stream to establish watches and
  reads to receive watch events. A single watch stream can multiplex many distinct
  watches by tagging events with per-watch identifiers. This multiplexing helps reducing
  the memory footprint and connection overhead on the core etcd cluster.

  Watches make three guarantees about events:

    * Ordered - events are ordered by revision; an event will never appear on a watch
      if it precedes an event in time that has already been posted.
    * Reliable - a sequence of events will never drop any subsequence of events; if
      there are events ordered in time as `a` < `b` < `c`, then if the watch receives events
      `a` and `c`, it is guaranteed to receive `b`.
    * Atomic - a list of events is guaranteed to encompass complete revisions; updates in
      the same revision over multiple keys will not be split over several lists of events.

  ## Options

  `watch_params` accepts the following options:

    * `:range_end` - the key range to watch.
    * `:prefix` - if true, sets up `:range_end` as `a+1`.
    * `:from_key` - if true, sets up `:range_end` as `key` to represent all keys after
      `key` argument.
    * `:start_revision` - an optional revision for where to inclusively begin watching.
      If not given, it will stream events following the revision of the watch creation
      response header revision. The entire available event history can be watched starting
      from the last compaction revision.
    * `:filters` - A list of event types to filter away at server side.
    * `:prev_kv` - when set, the watch receives the key-value data from before the event
      happens. This is useful for knowing what data has been overwritten.
    * `:timeout` - indicates max time to wait for a response. Defaults to `:infinity`.

  ## Watch events

  In response to a `watch`, the client process receives an `:etcd_watch_response` message:

      {:etcd_watch_response,
        %{
          header: %{
            cluster_id: 16182920199522267672,
            member_id: 9975446501980398855,
            raft_term: 13,
            revision: 47068291
          },
          watch_id: 1,
          created: false,
          canceled: false,
          compact_revision: 0,
          events: [
            ...
          ]
        }}

    * `:watch_id` - the ID of the watch that corresponds to the response. As watch
      streams are recreated during reconnections, the watch ID is exposed only for
      informative purposes.
    * `:created` - set to `true` if the response is for a create watch request. The
      client should store the ID and expect to receive events for the watch on the
      stream. All events sent to the created watcher will have the same `watch_id`.
    * `:canceled` - set to `true` if the response is for a cancel watch request. No
      further events will be sent to the canceled watcher.
    * `:compact_revision` - set to the minimum historical revision available to etcd
      if a watcher tries watching at a compacted revision. This happens when creating
      a watcher at a compacted revision or the watcher cannot catch up with the
      progress of the key-value store. The watcher will be canceled; creating new
      watches with the same start_revision will fail.
    * `:events` - a list of new events in sequence corresponding to the given watch ID.

  ## Events

  Every change to every key is represented with event messages. An event message
  provides both the data and the type of update:

      %{
        kv: %{
          create_revision: 45178185,
          key: "foo",
          lease: 4658271320497843197,
          mod_revision: 47068291,
          value: "bar",
          version: 112815
        },
        type: :PUT
      }

    * `:type` - the kind of event. A `:PUT` type indicates new data has been stored to
      the key. A `:DELETE` indicates the key was deleted.
    * `:kv` - the KeyValue associated with the event. A `:PUT` event contains current
      key-value pair. A `:PUT` event with `:version` 1 indicates the creation of a key.
      A `:DELETE` event contains the deleted key with its modification revision set to
      the revision of deletion.
    * `:prev_kv` - the key-value pair for the key from the revision immediately before
      the event. To save bandwidth, it is only filled out if the watch has explicitly
      enabled it.
  """
  @spec watch(conn, watching_process, Types.key(), [Types.watch_opt()], timeout) ::
          :ok | {:error, Mint.Types.error()}
  def watch(conn, watching_process, key, opts \\ [], timeout \\ @default_timeout) do
    EtcdEx.Connection.watch(conn, watching_process, key, opts, timeout)
  end

  @doc """
  Cancels a watch.
  """
  @spec cancel_watch(conn, watching_process, timeout) ::
          :ok | {:error, Mint.Types.error()}
  def cancel_watch(conn, watching_process, timeout \\ @default_timeout) do
    EtcdEx.Connection.cancel_watch(conn, watching_process, timeout)
  end

  @doc """
  List watches started by the watching process.
  """
  @spec list_watches(conn, watching_process, timeout) ::
          [{watch_ref, Types.key(), [Types.watch_opt()]}]
  def list_watches(conn, watching_process, timeout \\ @default_timeout) do
    EtcdEx.Connection.list_watches(conn, watching_process, timeout)
  end
end

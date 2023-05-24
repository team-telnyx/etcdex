defmodule EtcdEx.Types do
  @moduledoc """
  Etcd-related types.
  """

  @type key :: binary
  @type value :: binary
  @type range_end :: binary
  @type lease_id :: integer
  @type limit :: non_neg_integer
  @type revision :: pos_integer
  @type sort :: {sort_target, sort_order}
  @type sort_target :: :KEY | :VERSION | :VALUE | :CREATE | :MOD
  @type sort_order :: :NONE | :ASCEND | :DESCEND
  @type ttl :: pos_integer

  @type peer_url :: binary
  @type member_id :: pos_integer
  @type name :: binary

  @type filters :: [filter]
  @type filter :: :NOPUT | :NODELETE

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

  @type put_opt ::
          {:lease, lease_id}
          | {:prev_kv, boolean}
          | {:ignore_value, boolean}
          | {:ignore_lease, boolean}

  @type delete_opt ::
          {:range_end, range_end}
          | {:prefix, boolean}
          | {:from_key, boolean}
          | {:prev_kv, boolean}

  @type watch_opt ::
          {:range_end, range_end}
          | {:prefix, boolean}
          | {:from_key, boolean}
          | {:start_revision, revision}
          | {:filters, filters}
          | {:prev_kv, boolean}
          | {:progress_notify, boolean}

  @type ttl_opt ::
          {:keys, boolean}

  @type watch_id :: integer

  @type response ::
          {:status, Mint.Types.request_ref(), Mint.Types.status()}
          | {:headers, Mint.Types.request_ref(), Mint.Types.headers()}
          | {:data, Mint.Types.request_ref(), map}
          | {:done, Mint.Types.request_ref()}
          | {:error, Mint.Types.request_ref(), reason :: term}
end

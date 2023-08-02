defmodule EtcdEx.Proto.AlarmType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:NONE, 0)
  field(:NOSPACE, 1)
  field(:CORRUPT, 2)
end

defmodule EtcdEx.Proto.RangeRequest.SortOrder do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:NONE, 0)
  field(:ASCEND, 1)
  field(:DESCEND, 2)
end

defmodule EtcdEx.Proto.RangeRequest.SortTarget do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:KEY, 0)
  field(:VERSION, 1)
  field(:CREATE, 2)
  field(:MOD, 3)
  field(:VALUE, 4)
end

defmodule EtcdEx.Proto.Compare.CompareResult do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:EQUAL, 0)
  field(:GREATER, 1)
  field(:LESS, 2)
  field(:NOT_EQUAL, 3)
end

defmodule EtcdEx.Proto.Compare.CompareTarget do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:VERSION, 0)
  field(:CREATE, 1)
  field(:MOD, 2)
  field(:VALUE, 3)
  field(:LEASE, 4)
end

defmodule EtcdEx.Proto.WatchCreateRequest.FilterType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:NOPUT, 0)
  field(:NODELETE, 1)
end

defmodule EtcdEx.Proto.AlarmRequest.AlarmAction do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:GET, 0)
  field(:ACTIVATE, 1)
  field(:DEACTIVATE, 2)
end

defmodule EtcdEx.Proto.HealthCheckResponse.ServingStatus do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:UNKNOWN, 0)
  field(:SERVING, 1)
  field(:NOT_SERVING, 2)
  field(:SERVICE_UNKNOWN, 3)
end

defmodule EtcdEx.Proto.ResponseHeader do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:cluster_id, 1, type: :uint64, json_name: "clusterId")
  field(:member_id, 2, type: :uint64, json_name: "memberId")
  field(:revision, 3, type: :int64)
  field(:raft_term, 4, type: :uint64, json_name: "raftTerm")
end

defmodule EtcdEx.Proto.RangeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:key, 1, type: :bytes)
  field(:range_end, 2, type: :bytes, json_name: "rangeEnd")
  field(:limit, 3, type: :int64)
  field(:revision, 4, type: :int64)

  field(:sort_order, 5,
    type: EtcdEx.Proto.RangeRequest.SortOrder,
    json_name: "sortOrder",
    enum: true
  )

  field(:sort_target, 6,
    type: EtcdEx.Proto.RangeRequest.SortTarget,
    json_name: "sortTarget",
    enum: true
  )

  field(:serializable, 7, type: :bool)
  field(:keys_only, 8, type: :bool, json_name: "keysOnly")
  field(:count_only, 9, type: :bool, json_name: "countOnly")
  field(:min_mod_revision, 10, type: :int64, json_name: "minModRevision")
  field(:max_mod_revision, 11, type: :int64, json_name: "maxModRevision")
  field(:min_create_revision, 12, type: :int64, json_name: "minCreateRevision")
  field(:max_create_revision, 13, type: :int64, json_name: "maxCreateRevision")
end

defmodule EtcdEx.Proto.RangeResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:kvs, 2, repeated: true, type: Mvccpb.KeyValue)
  field(:more, 3, type: :bool)
  field(:count, 4, type: :int64)
end

defmodule EtcdEx.Proto.PutRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:key, 1, type: :bytes)
  field(:value, 2, type: :bytes)
  field(:lease, 3, type: :int64)
  field(:prev_kv, 4, type: :bool, json_name: "prevKv")
  field(:ignore_value, 5, type: :bool, json_name: "ignoreValue")
  field(:ignore_lease, 6, type: :bool, json_name: "ignoreLease")
end

defmodule EtcdEx.Proto.PutResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:prev_kv, 2, type: Mvccpb.KeyValue, json_name: "prevKv")
end

defmodule EtcdEx.Proto.DeleteRangeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:key, 1, type: :bytes)
  field(:range_end, 2, type: :bytes, json_name: "rangeEnd")
  field(:prev_kv, 3, type: :bool, json_name: "prevKv")
end

defmodule EtcdEx.Proto.DeleteRangeResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:deleted, 2, type: :int64)
  field(:prev_kvs, 3, repeated: true, type: Mvccpb.KeyValue, json_name: "prevKvs")
end

defmodule EtcdEx.Proto.RequestOp do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof(:request, 0)

  field(:request_range, 1, type: EtcdEx.Proto.RangeRequest, json_name: "requestRange", oneof: 0)
  field(:request_put, 2, type: EtcdEx.Proto.PutRequest, json_name: "requestPut", oneof: 0)

  field(:request_delete_range, 3,
    type: EtcdEx.Proto.DeleteRangeRequest,
    json_name: "requestDeleteRange",
    oneof: 0
  )

  field(:request_txn, 4, type: EtcdEx.Proto.TxnRequest, json_name: "requestTxn", oneof: 0)
end

defmodule EtcdEx.Proto.ResponseOp do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof(:response, 0)

  field(:response_range, 1, type: EtcdEx.Proto.RangeResponse, json_name: "responseRange", oneof: 0)

  field(:response_put, 2, type: EtcdEx.Proto.PutResponse, json_name: "responsePut", oneof: 0)

  field(:response_delete_range, 3,
    type: EtcdEx.Proto.DeleteRangeResponse,
    json_name: "responseDeleteRange",
    oneof: 0
  )

  field(:response_txn, 4, type: EtcdEx.Proto.TxnResponse, json_name: "responseTxn", oneof: 0)
end

defmodule EtcdEx.Proto.Compare do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof(:target_union, 0)

  field(:result, 1, type: EtcdEx.Proto.Compare.CompareResult, enum: true)
  field(:target, 2, type: EtcdEx.Proto.Compare.CompareTarget, enum: true)
  field(:key, 3, type: :bytes)
  field(:version, 4, type: :int64, oneof: 0)
  field(:create_revision, 5, type: :int64, json_name: "createRevision", oneof: 0)
  field(:mod_revision, 6, type: :int64, json_name: "modRevision", oneof: 0)
  field(:value, 7, type: :bytes, oneof: 0)
  field(:lease, 8, type: :int64, oneof: 0)
  field(:range_end, 64, type: :bytes, json_name: "rangeEnd")
end

defmodule EtcdEx.Proto.TxnRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:compare, 1, repeated: true, type: EtcdEx.Proto.Compare)
  field(:success, 2, repeated: true, type: EtcdEx.Proto.RequestOp)
  field(:failure, 3, repeated: true, type: EtcdEx.Proto.RequestOp)
end

defmodule EtcdEx.Proto.TxnResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:succeeded, 2, type: :bool)
  field(:responses, 3, repeated: true, type: EtcdEx.Proto.ResponseOp)
end

defmodule EtcdEx.Proto.CompactionRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:revision, 1, type: :int64)
  field(:physical, 2, type: :bool)
end

defmodule EtcdEx.Proto.CompactionResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.HashRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.HashKVRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:revision, 1, type: :int64)
end

defmodule EtcdEx.Proto.HashKVResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:hash, 2, type: :uint32)
  field(:compact_revision, 3, type: :int64, json_name: "compactRevision")
end

defmodule EtcdEx.Proto.HashResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:hash, 2, type: :uint32)
end

defmodule EtcdEx.Proto.SnapshotRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.SnapshotResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:remaining_bytes, 2, type: :uint64, json_name: "remainingBytes")
  field(:blob, 3, type: :bytes)
end

defmodule EtcdEx.Proto.WatchRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  oneof(:request_union, 0)

  field(:create_request, 1,
    type: EtcdEx.Proto.WatchCreateRequest,
    json_name: "createRequest",
    oneof: 0
  )

  field(:cancel_request, 2,
    type: EtcdEx.Proto.WatchCancelRequest,
    json_name: "cancelRequest",
    oneof: 0
  )

  field(:progress_request, 3,
    type: EtcdEx.Proto.WatchProgressRequest,
    json_name: "progressRequest",
    oneof: 0
  )
end

defmodule EtcdEx.Proto.WatchCreateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:key, 1, type: :bytes)
  field(:range_end, 2, type: :bytes, json_name: "rangeEnd")
  field(:start_revision, 3, type: :int64, json_name: "startRevision")
  field(:progress_notify, 4, type: :bool, json_name: "progressNotify")
  field(:filters, 5, repeated: true, type: EtcdEx.Proto.WatchCreateRequest.FilterType, enum: true)
  field(:prev_kv, 6, type: :bool, json_name: "prevKv")
  field(:watch_id, 7, type: :int64, json_name: "watchId")
  field(:fragment, 8, type: :bool)
end

defmodule EtcdEx.Proto.WatchCancelRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:watch_id, 1, type: :int64, json_name: "watchId")
end

defmodule EtcdEx.Proto.WatchProgressRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.WatchResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:watch_id, 2, type: :int64, json_name: "watchId")
  field(:created, 3, type: :bool)
  field(:canceled, 4, type: :bool)
  field(:compact_revision, 5, type: :int64, json_name: "compactRevision")
  field(:cancel_reason, 6, type: :string, json_name: "cancelReason")
  field(:fragment, 7, type: :bool)
  field(:events, 11, repeated: true, type: Mvccpb.Event)
end

defmodule EtcdEx.Proto.LeaseGrantRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:TTL, 1, type: :int64)
  field(:ID, 2, type: :int64)
end

defmodule EtcdEx.Proto.LeaseGrantResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:ID, 2, type: :int64)
  field(:TTL, 3, type: :int64)
  field(:error, 4, type: :string)
end

defmodule EtcdEx.Proto.LeaseRevokeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :int64)
end

defmodule EtcdEx.Proto.LeaseRevokeResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.LeaseCheckpoint do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :int64)
  field(:remaining_TTL, 2, type: :int64, json_name: "remainingTTL")
end

defmodule EtcdEx.Proto.LeaseCheckpointRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:checkpoints, 1, repeated: true, type: EtcdEx.Proto.LeaseCheckpoint)
end

defmodule EtcdEx.Proto.LeaseCheckpointResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.LeaseKeepAliveRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :int64)
end

defmodule EtcdEx.Proto.LeaseKeepAliveResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:ID, 2, type: :int64)
  field(:TTL, 3, type: :int64)
end

defmodule EtcdEx.Proto.LeaseTimeToLiveRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :int64)
  field(:keys, 2, type: :bool)
end

defmodule EtcdEx.Proto.LeaseTimeToLiveResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:ID, 2, type: :int64)
  field(:TTL, 3, type: :int64)
  field(:grantedTTL, 4, type: :int64)
  field(:keys, 5, repeated: true, type: :bytes)
end

defmodule EtcdEx.Proto.LeaseLeasesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.LeaseStatus do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :int64)
end

defmodule EtcdEx.Proto.LeaseLeasesResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:leases, 2, repeated: true, type: EtcdEx.Proto.LeaseStatus)
end

defmodule EtcdEx.Proto.Member do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :uint64)
  field(:name, 2, type: :string)
  field(:peerURLs, 3, repeated: true, type: :string)
  field(:clientURLs, 4, repeated: true, type: :string)
  field(:isLearner, 5, type: :bool)
end

defmodule EtcdEx.Proto.MemberAddRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:peerURLs, 1, repeated: true, type: :string)
  field(:isLearner, 2, type: :bool)
end

defmodule EtcdEx.Proto.MemberAddResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:member, 2, type: EtcdEx.Proto.Member)
  field(:members, 3, repeated: true, type: EtcdEx.Proto.Member)
end

defmodule EtcdEx.Proto.MemberRemoveRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :uint64)
end

defmodule EtcdEx.Proto.MemberRemoveResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:members, 2, repeated: true, type: EtcdEx.Proto.Member)
end

defmodule EtcdEx.Proto.MemberUpdateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :uint64)
  field(:peerURLs, 2, repeated: true, type: :string)
end

defmodule EtcdEx.Proto.MemberUpdateResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:members, 2, repeated: true, type: EtcdEx.Proto.Member)
end

defmodule EtcdEx.Proto.MemberListRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.MemberListResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:members, 2, repeated: true, type: EtcdEx.Proto.Member)
end

defmodule EtcdEx.Proto.MemberPromoteRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:ID, 1, type: :uint64)
end

defmodule EtcdEx.Proto.MemberPromoteResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:members, 2, repeated: true, type: EtcdEx.Proto.Member)
end

defmodule EtcdEx.Proto.DefragmentRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.DefragmentResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.MoveLeaderRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:targetID, 1, type: :uint64)
end

defmodule EtcdEx.Proto.MoveLeaderResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AlarmRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:action, 1, type: EtcdEx.Proto.AlarmRequest.AlarmAction, enum: true)
  field(:memberID, 2, type: :uint64)
  field(:alarm, 3, type: EtcdEx.Proto.AlarmType, enum: true)
end

defmodule EtcdEx.Proto.AlarmMember do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:memberID, 1, type: :uint64)
  field(:alarm, 2, type: EtcdEx.Proto.AlarmType, enum: true)
end

defmodule EtcdEx.Proto.AlarmResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:alarms, 2, repeated: true, type: EtcdEx.Proto.AlarmMember)
end

defmodule EtcdEx.Proto.StatusRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.StatusResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:version, 2, type: :string)
  field(:dbSize, 3, type: :int64)
  field(:leader, 4, type: :uint64)
  field(:raftIndex, 5, type: :uint64)
  field(:raftTerm, 6, type: :uint64)
  field(:raftAppliedIndex, 7, type: :uint64)
  field(:errors, 8, repeated: true, type: :string)
  field(:dbSizeInUse, 9, type: :int64)
  field(:isLearner, 10, type: :bool)
end

defmodule EtcdEx.Proto.AuthEnableRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.AuthDisableRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.AuthenticateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:password, 2, type: :string)
end

defmodule EtcdEx.Proto.AuthUserAddRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:password, 2, type: :string)
  field(:options, 3, type: Authpb.UserAddOptions)
end

defmodule EtcdEx.Proto.AuthUserGetRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :string)
end

defmodule EtcdEx.Proto.AuthUserDeleteRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :string)
end

defmodule EtcdEx.Proto.AuthUserChangePasswordRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:password, 2, type: :string)
end

defmodule EtcdEx.Proto.AuthUserGrantRoleRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:user, 1, type: :string)
  field(:role, 2, type: :string)
end

defmodule EtcdEx.Proto.AuthUserRevokeRoleRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:role, 2, type: :string)
end

defmodule EtcdEx.Proto.AuthRoleAddRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :string)
end

defmodule EtcdEx.Proto.AuthRoleGetRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:role, 1, type: :string)
end

defmodule EtcdEx.Proto.AuthUserListRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.AuthRoleListRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3
end

defmodule EtcdEx.Proto.AuthRoleDeleteRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:role, 1, type: :string)
end

defmodule EtcdEx.Proto.AuthRoleGrantPermissionRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:perm, 2, type: Authpb.Permission)
end

defmodule EtcdEx.Proto.AuthRoleRevokePermissionRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:role, 1, type: :string)
  field(:key, 2, type: :bytes)
  field(:range_end, 3, type: :bytes, json_name: "rangeEnd")
end

defmodule EtcdEx.Proto.AuthEnableResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthDisableResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthenticateResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:token, 2, type: :string)
end

defmodule EtcdEx.Proto.AuthUserAddResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthUserGetResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:roles, 2, repeated: true, type: :string)
end

defmodule EtcdEx.Proto.AuthUserDeleteResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthUserChangePasswordResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthUserGrantRoleResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthUserRevokeRoleResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthRoleAddResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthRoleGetResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:perm, 2, repeated: true, type: Authpb.Permission)
end

defmodule EtcdEx.Proto.AuthRoleListResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:roles, 2, repeated: true, type: :string)
end

defmodule EtcdEx.Proto.AuthUserListResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:users, 2, repeated: true, type: :string)
end

defmodule EtcdEx.Proto.AuthRoleDeleteResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthRoleGrantPermissionResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.AuthRoleRevokePermissionResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.HealthCheckRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:service, 1, type: :string)
end

defmodule EtcdEx.Proto.HealthCheckResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:status, 1, type: EtcdEx.Proto.HealthCheckResponse.ServingStatus, enum: true)
end

defmodule EtcdEx.Proto.LockRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :bytes)
  field(:lease, 2, type: :int64)
end

defmodule EtcdEx.Proto.LockResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:key, 2, type: :bytes)
end

defmodule EtcdEx.Proto.UnlockRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:key, 1, type: :bytes)
end

defmodule EtcdEx.Proto.UnlockResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.CampaignRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :bytes)
  field(:lease, 2, type: :int64)
  field(:value, 3, type: :bytes)
end

defmodule EtcdEx.Proto.CampaignResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:leader, 2, type: EtcdEx.Proto.LeaderKey)
end

defmodule EtcdEx.Proto.LeaderKey do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :bytes)
  field(:key, 2, type: :bytes)
  field(:rev, 3, type: :int64)
  field(:lease, 4, type: :int64)
end

defmodule EtcdEx.Proto.LeaderRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:name, 1, type: :bytes)
end

defmodule EtcdEx.Proto.LeaderResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
  field(:kv, 2, type: Mvccpb.KeyValue)
end

defmodule EtcdEx.Proto.ResignRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:leader, 1, type: EtcdEx.Proto.LeaderKey)
end

defmodule EtcdEx.Proto.ResignResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

defmodule EtcdEx.Proto.ProclaimRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:leader, 1, type: EtcdEx.Proto.LeaderKey)
  field(:value, 2, type: :bytes)
end

defmodule EtcdEx.Proto.ProclaimResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:header, 1, type: EtcdEx.Proto.ResponseHeader)
end

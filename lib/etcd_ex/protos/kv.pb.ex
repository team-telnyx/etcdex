defmodule Mvccpb.Event.EventType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:PUT, 0)
  field(:DELETE, 1)
end

defmodule Mvccpb.KeyValue do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:key, 1, type: :bytes)
  field(:create_revision, 2, type: :int64, json_name: "createRevision")
  field(:mod_revision, 3, type: :int64, json_name: "modRevision")
  field(:version, 4, type: :int64)
  field(:value, 5, type: :bytes)
  field(:lease, 6, type: :int64)
end

defmodule Mvccpb.Event do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:type, 1, type: Mvccpb.Event.EventType, enum: true)
  field(:kv, 2, type: Mvccpb.KeyValue)
  field(:prev_kv, 3, type: Mvccpb.KeyValue, json_name: "prevKv")
end

defmodule Authpb.Permission.Type do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field :READ, 0
  field :WRITE, 1
  field :READWRITE, 2
end
defmodule Authpb.UserAddOptions do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field :no_password, 1, type: :bool, json_name: "noPassword"
end
defmodule Authpb.User do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field :name, 1, type: :bytes
  field :password, 2, type: :bytes
  field :roles, 3, repeated: true, type: :string
  field :options, 4, type: Authpb.UserAddOptions
end
defmodule Authpb.Permission do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field :permType, 1, type: Authpb.Permission.Type, enum: true
  field :key, 2, type: :bytes
  field :range_end, 3, type: :bytes, json_name: "rangeEnd"
end
defmodule Authpb.Role do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field :name, 1, type: :bytes
  field :keyPermission, 2, repeated: true, type: Authpb.Permission
end

defmodule Gogoproto.PbExtension do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto2

  extend Google.Protobuf.EnumOptions, :goproto_enum_prefix, 62001, optional: true, type: :bool

  extend Google.Protobuf.EnumOptions, :goproto_enum_stringer, 62021, optional: true, type: :bool

  extend Google.Protobuf.EnumOptions, :enum_stringer, 62022, optional: true, type: :bool

  extend Google.Protobuf.EnumOptions, :enum_customname, 62023, optional: true, type: :string

  extend Google.Protobuf.EnumValueOptions, :enumvalue_customname, 66001,
    optional: true,
    type: :string

  extend Google.Protobuf.FileOptions, :goproto_getters_all, 63001, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :goproto_enum_prefix_all, 63002, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :goproto_stringer_all, 63003, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :verbose_equal_all, 63004, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :face_all, 63005, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :gostring_all, 63006, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :populate_all, 63007, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :stringer_all, 63008, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :onlyone_all, 63009, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :equal_all, 63013, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :description_all, 63014, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :testgen_all, 63015, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :benchgen_all, 63016, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :marshaler_all, 63017, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :unmarshaler_all, 63018, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :stable_marshaler_all, 63019, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :sizer_all, 63020, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :goproto_enum_stringer_all, 63021,
    optional: true,
    type: :bool

  extend Google.Protobuf.FileOptions, :enum_stringer_all, 63022, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :unsafe_marshaler_all, 63023, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :unsafe_unmarshaler_all, 63024, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :goproto_extensions_map_all, 63025,
    optional: true,
    type: :bool

  extend Google.Protobuf.FileOptions, :goproto_unrecognized_all, 63026,
    optional: true,
    type: :bool

  extend Google.Protobuf.FileOptions, :gogoproto_import, 63027, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :protosizer_all, 63028, optional: true, type: :bool

  extend Google.Protobuf.FileOptions, :compare_all, 63029, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :goproto_getters, 64001, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :goproto_stringer, 64003, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :verbose_equal, 64004, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :face, 64005, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :gostring, 64006, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :populate, 64007, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :stringer, 67008, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :onlyone, 64009, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :equal, 64013, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :description, 64014, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :testgen, 64015, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :benchgen, 64016, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :marshaler, 64017, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :unmarshaler, 64018, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :stable_marshaler, 64019, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :sizer, 64020, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :unsafe_marshaler, 64023, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :unsafe_unmarshaler, 64024, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :goproto_extensions_map, 64025,
    optional: true,
    type: :bool

  extend Google.Protobuf.MessageOptions, :goproto_unrecognized, 64026, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :protosizer, 64028, optional: true, type: :bool

  extend Google.Protobuf.MessageOptions, :compare, 64029, optional: true, type: :bool

  extend Google.Protobuf.FieldOptions, :nullable, 65001, optional: true, type: :bool

  extend Google.Protobuf.FieldOptions, :embed, 65002, optional: true, type: :bool

  extend Google.Protobuf.FieldOptions, :customtype, 65003, optional: true, type: :string

  extend Google.Protobuf.FieldOptions, :customname, 65004, optional: true, type: :string

  extend Google.Protobuf.FieldOptions, :jsontag, 65005, optional: true, type: :string

  extend Google.Protobuf.FieldOptions, :moretags, 65006, optional: true, type: :string

  extend Google.Protobuf.FieldOptions, :casttype, 65007, optional: true, type: :string

  extend Google.Protobuf.FieldOptions, :castkey, 65008, optional: true, type: :string

  extend Google.Protobuf.FieldOptions, :castvalue, 65009, optional: true, type: :string

  extend Google.Protobuf.FieldOptions, :stdtime, 65010, optional: true, type: :bool

  extend Google.Protobuf.FieldOptions, :stdduration, 65011, optional: true, type: :bool
end

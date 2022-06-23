# EtcdEx

Elixir client for the etcd API v3 (gRPC based). All core features are
supported. It includes reconnection, transaction, software transactional
memory, high-level query builders and lease management, watchers.

## Installation

The package can be installed by adding `etcdex` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:etcdex, "~> 0.1"}
  ]
end
```

Documentation is available at [HexDocs](https://hexdocs.pm/etcdex).

## Usage

First, create a connection to your etcd cluster with:

```elixir
EtcdEx.start_link(name: MyApp.Etcd)
```

or add one to your supervision tree:

```elixir
Supervisor.start_link([
  {EtcdEx, name: MyApp.Etcd}
], strategy: :one_for_one)
```

Get a single key with:

```elixir
EtcdEx.get(MyApp.Etcd, "/foo")
```

or list all keys with `/foo` prefix using:

```elixir
EtcdEx.get(MyApp.Etcd, "/foo", prefix: true)
```

or list all keys after `/foo` using:

```elixir
EtcdEx.get(MyApp.Etcd, "/foo", from_key: true)
```

Check [the documentation](https://hexdocs.pm/etcdex) for other options.

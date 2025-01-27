# Changelog
## 2.0.0

* `ETCD` oprations no longer crash on timeout
* `ETCD` oprations now return an error tuple `{:error, :timeout}` on timeout

## 1.3.0

* update `protobuf` dependency to `~> 0.12`
* fix typespecs and add dialyzer
* support elixir `1.10` and higher

## 1.2.0

* Remove watch stream from conn after closing
* Send `{:etcd_watch_error, reason}` message to client process when watches fail to reconnect

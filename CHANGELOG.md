# Changelog

## 1.2.0

* Remove watch stream from conn after closing
* Send `{:etcd_watch_error, reason}` message to client process when watches fail to reconnect

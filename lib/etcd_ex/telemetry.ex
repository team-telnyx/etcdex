defmodule EtcdEx.Telemetry do
  @moduledoc """
  EtcdEx telemetry integration.

  All time measurements are in `:native` units.

  EtcdEx executes following events:

  ### Request start

  `[:etcdex, :request, :start]` - Executed when sending a request to Etcd cluster.

  #### Measurements

    * `system_time` - The system time.

  #### Metadata

    * `request` - Type of the request.
    * `args` - Arguments of the request.

  ### Request stop

  `[:etcdex, :request, :stop]` - Executed after receiving a response from Etcd cluster.

  #### Measurements

    * `duration` - Time taken from the request start event.

  #### Metadata

    * `request` - Type of the request.
    * `args` - Arguments of the request.
    * `result` - The result of the operation.

  ### Connect start

  `[:etcdex, :connect, :start]` - Executed before establishing connection to Etcd cluster.

  #### Measurements

    * `system_time` - The system time.

  #### Metadata

    * `scheme` - The scheme used in the connection.
    * `address` - The host address of the Etcd cluster.
    * `port` - The port of the Etcd cluster.

  ### Connect stop

  `[:etcdex, :connect, :stop]` - Executed when finished establishing connection (either successfully or not).

  #### Measurements

    * `duration` - Time take from the connect start event.

  #### Metadata

    * `scheme` - The scheme used in the connection.
    * `address` - The host address of the Etcd cluster.
    * `port` - The port of the Etcd cluster.
    * `error` - Error message received when trying to establish the connection, set only on unsuccessful attempts.

  ### Disconnect

  `[:etcdex, :disconnect]` - Executed when disconnected from Etcd cluster.

  #### Measurements

  * `system_time` - The system time.

  #### Metadata

    * `scheme` - The scheme used in the connection.
    * `address` - The host address of the Etcd cluster.
    * `port` - The port of the Etcd cluster.
    * `reason` - The disconnect reason.
  """

  @doc false
  def start(event, meta \\ %{}, extra_measurements \\ %{}) do
    start_time = System.monotonic_time()
    measurements = Map.merge(extra_measurements, %{start_time: System.system_time()})

    :telemetry.execute(
      [:etcdex, event, :start],
      measurements,
      meta
    )

    start_time
  end

  @doc false
  def stop(event, start_time, meta \\ %{}, extra_measurements \\ %{}) do
    end_time = System.monotonic_time()
    measurements = Map.merge(extra_measurements, %{duration: end_time - start_time})

    :telemetry.execute(
      [:etcdex, event, :stop],
      measurements,
      meta
    )
  end

  @doc false
  def event(event, meta, measurements) do
    :telemetry.execute([:etcdex, event], measurements, meta)
  end
end

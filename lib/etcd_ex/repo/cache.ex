defmodule EtcdEx.Repo.Cache do
  @moduledoc false

  use GenServer
  require Logger

  alias EtcdEx.Repo

  defstruct [
    :module,
    :conn,
    :prefix,
    :pubsub,
    :bootstrap_timeout,
    :bootstrap_backoff,
    :watch,
    :bootstrapped_from_static_data?
  ]

  def start_link(opts) do
    GenServer.start_link(
      __MODULE__,
      opts,
      name: opts[:module].cache_name()
    )
  end

  @impl true
  def init(opts) do
    :ets.new(
      opts[:module].cache_name(),
      [:protected, :named_table, read_concurrency: true]
    )

    state = %__MODULE__{
      conn: opts[:module].conn_name(),
      module: opts[:module],
      prefix: opts[:prefix],
      pubsub: opts[:pubsub],
      bootstrap_timeout: opts[:bootstrap_timeout],
      bootstrap_backoff: opts[:bootstrap_backoff],
      bootstrapped_from_static_data?: false
    }

    {:ok, state, {:continue, :bootstrap}}
  end

  @impl true
  def handle_continue(
        :bootstrap,
        %__MODULE__{module: module, prefix: prefix, pubsub: pubsub} = state
      ) do
    broadcast_event(:bootstrap_start, module, prefix, pubsub)
    {:noreply, do_bootstrap(state)}
  end

  @impl true
  def handle_call(
        {:put, key, value, opts},
        _from,
        %__MODULE__{module: module, conn: conn, prefix: prefix} = state
      ) do
    key = module.encode_key(key, prefix)
    value = module.encode_value(key, value)

    {:reply, EtcdEx.put(conn, key, value, opts), state}
  end

  def handle_call(
        {:delete, key, opts},
        _from,
        %__MODULE__{module: module, conn: conn, prefix: prefix} = state
      ) do
    key = module.encode_key(key, prefix)

    {:reply, EtcdEx.delete(conn, key, opts), state}
  end

  @impl true
  def handle_info({:etcd_watch_created, _ref}, state) do
    {:noreply, state}
  end

  def handle_info(
        {:etcd_watch_notify, ref, %{events: events, header: %{revision: revision}}},
        %__MODULE__{
          module: module,
          prefix: prefix,
          pubsub: pubsub,
          watch: %{ref: ref} = watch
        } = state
      ) do
    for event <- events do
      process_event(event, module, prefix, pubsub)
    end

    {:noreply, %{state | watch: Map.put(watch, :revision, revision)}}
  end

  def handle_info(
        {:etcd_watch_canceled, ref, reason},
        %__MODULE__{module: module, watch: %{ref: ref}} = state
      ) do
    Logger.error("#{module} etcd watch canceled #{inspect(reason)}")
    {:noreply, %{state | watch: nil}, {:continue, :bootstrap}}
  end

  def handle_info(
        {:etcd_watch_error, reason},
        %__MODULE__{module: module} = state
      ) do
    Logger.error("#{module} etcd watch error #{reason}")
    {:noreply, %{state | watch: nil}, {:continue, :bootstrap}}
  end

  defp do_bootstrap(%__MODULE__{module: module, bootstrap_backoff: backoff} = state) do
    case bootstrap_from_etcd(state) do
      {:ok, state} ->
        state

      _ ->
        state = bootstrap_from_static_data(state)
        Logger.error("#{module} bootstrap from etcd failed, retrying in #{inspect(backoff)}ms")

        :timer.sleep(backoff)
        do_bootstrap(state)
    end
  end

  defp bootstrap_from_etcd(
         %__MODULE__{
           module: module,
           conn: conn,
           prefix: prefix,
           pubsub: pubsub,
           bootstrap_timeout: timeout
         } = state
       ) do
    ## for testing purposes, we use __MODULE__.get_kvs/3 here instead of a direct call
    with {:ok, {revision, kvs}} <- get_kvs(conn, prefix, timeout),
         process_kvs(module, prefix, pubsub, kvs),
         {:ok, watch_ref} <- watch_prefix(conn, prefix, revision) do
      broadcast_event(:bootstrap_stop, module, prefix, pubsub)
      Logger.info("#{module} bootstrap from etcd successful")

      state = %{
        state
        | watch: %{ref: watch_ref, revision: revision},
          bootstrapped_from_static_data?: false
      }

      {:ok, state}
    else
      _ -> :error
    end
  catch
    _, _ -> :error
  end

  defp bootstrap_from_static_data(
         %__MODULE__{
           module: module,
           prefix: prefix,
           pubsub: pubsub,
           bootstrapped_from_static_data?: false
         } = state
       ) do
    case module.bootstrap_from_static_data() do
      {:ok, kvs} ->
        process_kvs(module, prefix, pubsub, kvs)
        broadcast_event(:bootstrap_stop, module, prefix, pubsub)
        Logger.info("#{module} bootstrap from static data successful")

        %{state | bootstrapped_from_static_data?: true}

      _ ->
        state
    end
  end

  defp bootstrap_from_static_data(%__MODULE__{bootstrapped_from_static_data?: true} = state),
    do: state

  defp get_kvs(conn, prefix, timeout) do
    case EtcdEx.get(conn, prefix, [prefix: true], timeout) do
      {:ok, %{header: %{revision: revision}, kvs: kvs}} ->
        {:ok, {revision, kvs}}

      {:error, reason} ->
        Logger.error("etcd get #{prefix} failed: #{inspect(reason)}")
        :error
    end
  end

  defp watch_prefix(conn, prefix, revision) do
    case EtcdEx.watch(conn, self(), prefix, prefix: true, start_revision: revision) do
      {:ok, ref} ->
        {:ok, ref}

      {:error, reason} ->
        Logger.error("etcd watch #{prefix} failed: #{inspect(reason)}")
        :error
    end
  end

  defp process_kvs(module, prefix, pubsub, kvs) do
    :ets.delete_all_objects(module.cache_name())

    for kv <- kvs do
      process_event(%{type: :PUT, kv: kv}, module, prefix, pubsub)
    end
  end

  defp process_event(%{type: :PUT, kv: %{key: key, value: value}}, module, prefix, pubsub) do
    with {:key, {:ok, key}} <- {:key, module.decode_key(key, prefix)},
         {:value, {:ok, value}} <- {:value, module.decode_value(key, value)} do
      :ets.insert(module.cache_name(), {key, value})
      broadcast_event({:PUT, key, value}, module, prefix, pubsub)
    else
      {:key, {:error, :ignore}} ->
        :ok

      {:key, {:error, reason}} ->
        Logger.error("#{module} failed to decode key #{key} (#{reason})")

      {:value, _} ->
        Logger.error("#{module} failed to decode value for key #{key}")
    end
  end

  defp process_event(%{type: :DELETE, kv: %{key: key}}, module, prefix, pubsub) do
    case module.decode_key(key, prefix) do
      {:ok, key} ->
        :ets.delete(module.cache_name(), key)
        broadcast_event({:DELETE, key}, module, prefix, pubsub)

      {:error, :ignore} ->
        :ok

      {:error, reason} ->
        Logger.error("#{module} failed to decode key #{key} (#{reason})")
    end
  end

  defp broadcast_event(_event, _module, _prefix, _pubsub = nil), do: :ok

  defp broadcast_event(:bootstrap_start, module, _prefix, pubsub) do
    maybe_broadcast(pubsub, Repo.pubsub_topic(module), {:bootstrap_start, module})
  end

  defp broadcast_event(:bootstrap_stop, module, _prefix, pubsub) do
    maybe_broadcast(pubsub, Repo.pubsub_topic(module), {:bootstrap_stop, module})
  end

  defp broadcast_event(event, module, prefix, pubsub) do
    key =
      case event do
        {:PUT, key, _value} -> key
        {:DELETE, key} -> key
      end

    maybe_broadcast(pubsub, Repo.pubsub_topic(module), event)
    maybe_broadcast(pubsub, Repo.pubsub_topic(key, module, prefix), event)
  end

  defp maybe_broadcast(pubsub, topic, event) do
    case Code.ensure_compiled(Phoenix.PubSub) do
      {:module, module} ->
        module.broadcast(pubsub, topic, event)

      {:error, _} ->
        Logger.error("Unable to broadcast event, Phoenix.PubSub not loaded.")
        :noop
    end
  end
end

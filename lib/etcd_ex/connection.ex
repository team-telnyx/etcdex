defmodule EtcdEx.Connection do
  @moduledoc false

  use Connection

  alias EtcdEx.{KeepAliveTimer, Telemetry}

  require Logger

  defstruct [
    :env,
    :endpoint,
    :options,
    :keep_alive_timer,
    pending_requests: %{},
    watch_streams: %{}
  ]

  @type t :: pid | GenServer.name()

  @default_endpoint {:http, "localhost", 2379, []}
  @default_backoff :timer.seconds(5)

  @closed %Mint.TransportError{reason: :closed}

  @unary_verbs [
    :get,
    :put,
    :delete,
    :compact,
    :grant,
    :revoke,
    :keep_alive,
    :ttl,
    :leases,
    :lock,
    :unlock,
    :add_member,
    :remove_member,
    :update_member,
    :list_members,
    :promote_member
  ]

  @doc false
  def unary(conn, fun, args, timeout) do
    try do
      Connection.call(conn, {:unary, fun, args}, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc false
  def watch(conn, watching_process, key, opts, timeout) do
    try do
      Connection.call(conn, {:watch, watching_process, key, opts}, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc false
  def cancel_watch(conn, watching_process, timeout) do
    try do
      Connection.call(conn, {:cancel_watch, watching_process}, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc false
  def list_watches(conn, watching_process, timeout) do
    try do
      Connection.call(conn, {:list_watches, watching_process}, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  @doc false
  def child_spec(options) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [options]}
    }
  end

  @doc false
  def start_link(options) do
    start_opts =
      case Keyword.fetch(options, :name) do
        {:ok, name} when is_atom(name) ->
          [name: name]

        {:ok, other} ->
          raise ArgumentError, "expected :name to be an atom, got: #{inspect(other)}"

        :error ->
          []
      end

    endpoint =
      case Keyword.fetch(options, :endpoint) do
        {:ok, {scheme, address, port, opts}} ->
          {scheme, address, port, opts}

        {:ok, other} ->
          raise ArgumentError,
                "bad :endpoint, got: #{inspect(other)}"

        :error ->
          @default_endpoint
      end

    options = Keyword.take(options, [:keep_alive_interval, :keep_alive_timeout])

    Connection.start_link(__MODULE__, {endpoint, options}, start_opts)
  end

  @impl Connection
  def init({endpoint, options}) do
    {:connect, :init, %__MODULE__{endpoint: endpoint, options: options}}
  end

  @impl Connection
  def connect(_info, state) do
    {scheme, address, port, opts} = state.endpoint

    metadata = %{
      scheme: scheme,
      address: address,
      port: port
    }

    start_time = Telemetry.start(:connect, metadata, %{system_time: System.system_time()})

    case Mint.HTTP2.connect(scheme, address, port, opts) do
      {:ok, conn} ->
        Telemetry.stop(:connect, start_time, metadata)
        env = EtcdEx.Mint.wrap(conn)
        keep_alive_timer = KeepAliveTimer.start(state.options)
        state = %{state | env: env, keep_alive_timer: keep_alive_timer}
        {:ok, reconnect_watches(state)}

      {:error, reason} ->
        metadata = Map.put(metadata, :error, reason)
        Telemetry.stop(:connect, start_time, metadata)

        {:backoff, Keyword.get(state.options, :backoff, @default_backoff), state}
    end
  end

  @impl Connection
  def disconnect(reason, state) do
    {scheme, address, port, _opts} = state.endpoint

    metadata = %{
      scheme: scheme,
      address: address,
      port: port,
      reason: reason
    }

    Telemetry.event(:disconnect, metadata, %{system_time: System.system_time()})

    state.pending_requests
    |> Enum.each(fn
      {_request_ref, {:unary, from, _status, _metadata}} ->
        Connection.reply(from, {:error, reason})

      {_request_ref, {:watch, _watching_process}} ->
        :ok
    end)

    unless state.env == nil do
      state.env
      |> EtcdEx.Mint.unwrap()
      |> Mint.HTTP.close()
    end

    keep_alive_timer = KeepAliveTimer.clear(state.keep_alive_timer)

    state = %{state | env: nil, keep_alive_timer: keep_alive_timer, pending_requests: %{}}

    {:connect, :reconnect, state}
  end

  @impl Connection
  def handle_call(_, _from, %{env: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:unary, fun, args}, from, state) when fun in @unary_verbs do
    start_metadata = %{request: fun, args: args}
    start_time = Telemetry.start(:request, start_metadata, %{system_time: System.system_time()})

    request_metadata = Map.put(start_metadata, :start_time, start_time)
    result = apply(EtcdEx.Mint, fun, [state.env] ++ args)
    handle_unary_request(result, from, state, request_metadata)
  end

  def handle_call({:watch, watching_process, key, opts}, _from, state) do
    {reply, state} = do_watch(watching_process, key, opts, state)

    {:reply, reply, state}
  end

  def handle_call({:cancel_watch, watching_process}, _from, state) do
    {reply, state} = do_cancel_watch(watching_process, state)

    {:reply, reply, state}
  end

  def handle_call({:list_watches, watching_process}, _from, state) do
    reply =
      case Map.get(state.watch_streams, watching_process) do
        nil ->
          []

        %{watch_stream: watch_stream} ->
          watch_stream.watches
          |> Enum.map(fn {watch_ref, %{key: key, opts: opts}} ->
            {watch_ref, key, opts}
          end)
      end

    {:reply, reply, state}
  end

  @impl Connection
  def handle_info({:DOWN, _ref, :process, watching_process, _info}, state) do
    {_reply, state} = do_cancel_watch(watching_process, state)

    {:noreply, state}
  end

  def handle_info(:keep_alive, state) do
    case Mint.HTTP2.ping(state.env.conn) do
      {:ok, conn, request_ref} ->
        env = %{state.env | conn: conn}
        keep_alive_timer = KeepAliveTimer.start_timeout_timer(state.keep_alive_timer, request_ref)
        {:noreply, %{state | env: env, keep_alive_timer: keep_alive_timer}}

      {:error, conn, reason} ->
        env = %{state.env | conn: conn}
        state = %{state | env: env}

        if reason == @closed,
          do: {:disconnect, :closed, state},
          else: {:noreply, state}
    end
  end

  def handle_info(:keep_alive_expired, state),
    do: {:disconnect, :keep_alive_timeout, state}

  def handle_info(message, state) do
    case EtcdEx.Mint.stream(state.env, message) do
      {:ok, env, responses} ->
        keep_alive_timer = KeepAliveTimer.reset_interval_timer(state.keep_alive_timer)

        state =
          handle_responses(responses, %{state | env: env, keep_alive_timer: keep_alive_timer})

        {:noreply, state}

      {:error, env, reason, responses} ->
        state = handle_responses(responses, %{state | env: env})

        {:disconnect, reason, state}

      :unknown ->
        # This may happen when reconnecting, as the process may receive
        # {:tcp_closed, port} but for a port already closed.
        {:noreply, state}
    end
  end

  defp handle_unary_request({:ok, env, request_ref}, from, state, metadata) do
    pending_requests = Map.put(state.pending_requests, request_ref, {:unary, from, [], metadata})

    {:noreply, %{state | env: env, pending_requests: pending_requests}}
  end

  defp handle_unary_request({:error, env, reason}, _from, state, metadata) do
    result = {:error, reason}

    end_metadata =
      metadata
      |> Map.take([:request, :args])
      |> Map.put(:result, result)

    Telemetry.stop(:request, metadata.start_time, end_metadata)

    {:reply, result, %{state | env: env}}
  end

  defp handle_responses(responses, state) do
    Enum.reduce(responses, state, &process_response/2)
  end

  defp process_response({:status, request_ref, status}, state) do
    case Map.get(state.pending_requests, request_ref) do
      nil ->
        # This is the case when caller closes the watch stream, but there are messages
        # on the queue to be processed. In this case they are just ignored.
        state

      {:unary, from, [], metadata} ->
        pending_requests =
          Map.put(state.pending_requests, request_ref, {:unary, from, [status], metadata})

        %{state | pending_requests: pending_requests}

      {:watch, _pid} ->
        state
    end
  end

  defp process_response({:headers, request_ref, headers}, state) do
    case Map.get(state.pending_requests, request_ref) do
      nil ->
        # This is the case when caller closes the watch stream, but there are messages
        # on the queue to be processed. In this case they are just ignored.
        state

      {:unary, from, acc, metadata} ->
        pending_requests =
          Map.put(state.pending_requests, request_ref, {:unary, from, acc ++ [headers], metadata})

        %{state | pending_requests: pending_requests}

      {:watch, _pid} ->
        state
    end
  end

  defp process_response({:data, request_ref, data} = response, state) do
    case Map.get(state.pending_requests, request_ref) do
      nil ->
        # This is the case when caller closes the watch stream, but there are messages
        # on the queue to be processed. In this case they are just ignored.
        state

      {:unary, from, response, metadata} ->
        pending_requests =
          Map.put(
            state.pending_requests,
            request_ref,
            {:unary, from, response ++ [data], metadata}
          )

        %{state | pending_requests: pending_requests}

      {:watch, watching_process} ->
        %{watch_stream: watch_stream} = Map.fetch!(state.watch_streams, watching_process)

        case EtcdEx.WatchStream.stream(state.env, request_ref, watch_stream, response) do
          {:ok, env, watch_stream, :empty} ->
            watch_streams =
              Map.update!(
                state.watch_streams,
                watching_process,
                &%{&1 | watch_stream: watch_stream}
              )

            %{state | env: env, watch_streams: watch_streams}

          {:ok, env, watch_stream, response} ->
            send(watching_process, response)

            state =
              if Enum.empty?(watch_stream.watches) do
                watch_streams = Map.delete(state.watch_streams, watching_process)
                pending_requests = Map.delete(state.pending_requests, request_ref)

                %{state | watch_streams: watch_streams, pending_requests: pending_requests}
              else
                watch_streams =
                  Map.update!(
                    state.watch_streams,
                    watching_process,
                    &%{&1 | watch_stream: watch_stream}
                  )

                %{state | watch_streams: watch_streams}
              end

            %{state | env: env}

          {:error, env, reason} ->
            Logger.warn("error when sending request: #{inspect(reason)}")
            %{state | env: env}
        end
    end
  end

  defp process_response({:done, request_ref}, state) do
    case Map.get(state.pending_requests, request_ref) do
      nil ->
        :ok

      {:unary, from, [status, headers | data], metadata} ->
        grpc_status = :proplists.get_value("grpc-status", headers)
        grpc_message = :proplists.get_value("grpc-message", headers)

        result =
          case {status, grpc_status} do
            {200, :undefined} ->
              case List.first(data) do
                nil -> :ok
                data -> {:ok, data}
              end

            {200, _} ->
              {:error,
               {:grpc_error,
                %{grpc_status: String.to_integer(grpc_status), grpc_message: grpc_message}}}

            {status, _} ->
              {:error, {:http_error, %{status: status}}}
          end

        end_metadata =
          metadata
          |> Map.take([:request, :args])
          |> Map.put(:result, result)

        Telemetry.stop(:request, metadata.start_time, end_metadata)

        Connection.reply(from, result)
    end

    pending_requests = Map.delete(state.pending_requests, request_ref)
    %{state | pending_requests: pending_requests}
  end

  defp process_response({:error, request_ref, reason}, state) do
    case Map.fetch!(state.pending_requests, request_ref) do
      {:unary, from, _, metadata} ->
        result = {:error, reason}

        end_metadata =
          metadata
          |> Map.take([:request, :args])
          |> Map.put(:result, result)

        Telemetry.stop(:request, metadata.start_time, end_metadata)

        Connection.reply(from, {:error, reason})
        pending_requests = Map.delete(state.pending_requests, request_ref)
        %{state | pending_requests: pending_requests}

      {:watch, watching_process} ->
        send(watching_process, {:etcd_watch_error, reason})
        pending_requests = Map.delete(state.pending_requests, request_ref)
        watch_streams = Map.delete(state.watch_streams, watching_process)
        %{state | pending_requests: pending_requests, watch_streams: watch_streams}
    end
  end

  defp process_response({:pong, request_ref}, state) do
    keep_alive_timer = KeepAliveTimer.clear_after_timer(state.keep_alive_timer, request_ref)
    %{state | keep_alive_timer: keep_alive_timer}
  end

  defp do_watch(watching_process, key, opts, state) do
    with {:ok, state} <- do_open_watch_stream(watching_process, state),
         {:ok, watch_ref, state} <- do_send_watch(watching_process, key, opts, state) do
      {{:ok, watch_ref}, state}
    else
      {:error, state, reason} -> {{:error, reason}, state}
    end
  end

  defp do_open_watch_stream(watching_process, state) do
    case Map.get(state.watch_streams, watching_process) do
      nil ->
        case EtcdEx.Mint.open_watch_stream(state.env) do
          {:ok, env, request_ref} ->
            monitor_ref = Process.monitor(watching_process)

            watch_stream = %{
              watch_stream: EtcdEx.WatchStream.new(),
              request_ref: request_ref,
              monitor_ref: monitor_ref
            }

            watch_streams = Map.put(state.watch_streams, watching_process, watch_stream)

            pending_requests =
              Map.put(state.pending_requests, request_ref, {:watch, watching_process})

            state = %{
              state
              | env: env,
                watch_streams: watch_streams,
                pending_requests: pending_requests
            }

            {:ok, state}

          {:error, env, reason} ->
            {:error, %{state | env: env}, reason}
        end

      _ ->
        {:ok, state}
    end
  end

  defp do_send_watch(watching_process, key, opts, state) do
    %{watch_stream: watch_stream, request_ref: request_ref} =
      Map.fetch!(state.watch_streams, watching_process)

    case EtcdEx.WatchStream.watch(state.env, request_ref, watch_stream, key, opts) do
      {:ok, env, watch_stream, watch_ref} ->
        watch_streams =
          Map.update!(state.watch_streams, watching_process, &%{&1 | watch_stream: watch_stream})

        {:ok, watch_ref, %{state | env: env, watch_streams: watch_streams}}

      {:error, env, reason} ->
        {:error, %{state | env: env}, reason}
    end
  end

  defp do_cancel_watch(watching_process, state) do
    case Map.get(state.watch_streams, watching_process) do
      nil ->
        {{:error, :not_found}, state}

      %{request_ref: request_ref, monitor_ref: monitor_ref, watch_stream: watch_stream} ->
        %{env: env} = state

        env =
          Enum.reduce(watch_stream.watches, env, fn {watch_ref, _}, env ->
            case EtcdEx.WatchStream.cancel_watch(env, request_ref, watch_stream, watch_ref) do
              {:ok, env} -> env
              {:error, env, _reason} -> env
            end
          end)

        case EtcdEx.Mint.close_watch_stream(env, request_ref) do
          {:ok, env} ->
            Process.demonitor(monitor_ref)
            state = %{state | env: env}
            {:ok, state}

          {:error, env, reason} ->
            {{:error, reason}, %{state | env: env}}
        end
    end
  end

  defp reconnect_watches(state) do
    state.watch_streams
    |> Map.keys()
    |> Enum.reduce(state, fn watching_process, state ->
      with {:ok, env, request_ref} <- EtcdEx.Mint.open_watch_stream(state.env),
           {:ok, state} <- reconnect_watch(watching_process, request_ref, %{state | env: env}) do
        state
      else
        {:error, env, reason} ->
          Logger.warn("error reopening watch streams: #{inspect(reason)}")
          send(watching_process, {:etcd_watch_error, reason})
          %{state | env: env, watch_streams: Map.delete(state.watch_streams, watching_process)}
      end
    end)
  end

  defp reconnect_watch(watching_process, request_ref, state) do
    %{watch_stream: watch_stream} = Map.fetch!(state.watch_streams, watching_process)

    case EtcdEx.WatchStream.reconnect(state.env, request_ref, watch_stream) do
      {:ok, env, watch_stream} ->
        pending_requests =
          Map.put(state.pending_requests, request_ref, {:watch, watching_process})

        watch_streams =
          Map.update!(
            state.watch_streams,
            watching_process,
            &%{&1 | watch_stream: watch_stream, request_ref: request_ref}
          )

        {:ok,
         %{state | env: env, pending_requests: pending_requests, watch_streams: watch_streams}}

      {:error, env, reason} ->
        {:error, env, reason}
    end
  end
end

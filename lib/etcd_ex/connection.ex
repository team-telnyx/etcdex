defmodule EtcdEx.Connection do
  @moduledoc """
  Represents a connection to Etcd.
  """

  use Connection

  alias EtcdEx.KeepAliveTimer

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

  @doc false
  def unary(conn, fun, args, timeout),
    do: Connection.call(conn, {:unary, fun, args}, timeout)

  @doc false
  def open_watch_stream(conn, timeout),
    do: Connection.call(conn, :open_watch_stream, timeout)

  @doc false
  def watch(conn, watch_ref, key, opts, timeout),
    do: Connection.call(conn, {:watch, watch_ref, key, opts}, timeout)

  @doc false
  def cancel_watch(conn, watch_ref, watch_id, timeout),
    do: Connection.call(conn, {:cancel_watch, watch_ref, watch_id}, timeout)

  @doc false
  def close_watch_stream(conn, request_ref, timeout),
    do: Connection.call(conn, {:close_watch_stream, request_ref}, timeout)

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

    case Mint.HTTP2.connect(scheme, address, port, opts) do
      {:ok, conn} ->
        {:ok,
         %{
           state
           | env: EtcdEx.Mint.wrap(conn),
             keep_alive_timer: KeepAliveTimer.start(state.options)
         }}

      {:error, _reason} ->
        {:backoff, @default_backoff, state}
    end
  end

  @impl Connection
  def disconnect(reason, state) do
    state.pending_requests
    |> Enum.each(fn
      {_request_ref, {:unary, from, _}} -> Connection.reply(from, {:error, reason})
      {_request_ref, {:watch, pid}} -> send(pid, {:etcd_watch_error, reason})
    end)

    state.env
    |> EtcdEx.Mint.unwrap()
    |> Mint.HTTP.close()

    {:connect, :reconnect, %{state | env: nil, pending_requests: %{}}}
  end

  @impl Connection
  def handle_call({:unary, fun, args}, from, state)
      when fun in [:get, :put, :delete, :grant, :revoke, :keep_alive, :ttl, :leases] do
    if state.env == nil do
      {:reply, {:error, :not_connected}, state}
    else
      result = apply(EtcdEx.Mint, fun, [state.env] ++ args)
      handle_unary_request(result, from, state)
    end
  end

  def handle_call(:open_watch_stream, {pid, _tag}, state) do
    case EtcdEx.Mint.open_watch_stream(state.env) do
      {:ok, env, request_ref} ->
        pending_requests = Map.put(state.pending_requests, request_ref, {:watch, pid})
        watch_streams = Map.put(state.watch_streams, request_ref, %{pending: :queue.new()})

        state = %{
          state
          | env: env,
            pending_requests: pending_requests,
            watch_streams: watch_streams
        }

        {:reply, {:ok, request_ref}, state}

      {:error, env, reason} ->
        {:reply, {:error, reason}, %{state | env: env}}
    end
  end

  def handle_call({:watch, request_ref, key, opts}, {pid, _tag} = from, state) do
    case Map.get(state.pending_requests, request_ref) do
      nil ->
        {:reply, {:error, :not_found}, state}

      {:watch, ^pid} ->
        case EtcdEx.Mint.watch(state.env, request_ref, key, opts) do
          {:ok, env} ->
            %{pending: pending} = Map.fetch!(state.watch_streams, request_ref)

            watch_streams =
              Map.put(state.watch_streams, request_ref, %{pending: :queue.in(from, pending)})

            {:noreply, %{state | env: env, watch_streams: watch_streams}}

          {:error, env, reason} ->
            {:reply, {:error, reason}, %{state | env: env}}
        end

      {:watch, _pid} ->
        {:reply, {:error, :not_on_controlling_process}, state}
    end
  end

  def handle_call({:cancel_watch, request_ref, watch_id}, {pid, _tag} = from, state) do
    case Map.get(state.pending_requests, request_ref) do
      nil ->
        {:reply, {:error, :not_found}, state}

      {:watch, ^pid} ->
        case EtcdEx.Mint.cancel_watch(state.env, request_ref, watch_id) do
          {:ok, env} ->
            %{pending: pending} = Map.fetch!(state.watch_streams, request_ref)

            watch_streams =
              Map.put(state.watch_streams, request_ref, %{pending: :queue.in(from, pending)})

            {:noreply, %{state | env: env, watch_streams: watch_streams}}

          {:error, env, reason} ->
            {:reply, {:error, reason}, %{state | env: env}}
        end

      {:watch, _pid} ->
        {:reply, {:error, :not_on_controlling_process}, state}
    end
  end

  def handle_call({:close_watch_stream, request_ref}, {pid, _tag}, state) do
    case Map.get(state.pending_requests, request_ref) do
      nil ->
        {:reply, {:error, :not_found}, state}

      {:watch, ^pid} ->
        case EtcdEx.Mint.close_watch_stream(state.env, request_ref) do
          {:ok, env} ->
            pending_requests = Map.delete(state.pending_requests, request_ref)
            {:reply, :ok, %{state | env: env, pending_requests: pending_requests}}

          {:error, env, reason} ->
            {:reply, {:error, reason}, %{state | env: env}}
        end

      {:watch, _pid} ->
        {:reply, {:error, :not_on_controlling_process}, state}
    end
  end

  @impl Connection
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
    end
  end

  defp handle_unary_request({:ok, env, request_ref}, from, state) do
    pending_requests = Map.put(state.pending_requests, request_ref, {:unary, from, []})

    {:noreply, %{state | env: env, pending_requests: pending_requests}}
  end

  defp handle_unary_request({:error, env, reason}, _from, state) do
    {:reply, {:error, reason}, %{state | env: env}}
  end

  defp handle_responses(responses, state) do
    Enum.reduce(responses, state, &process_response/2)
  end

  defp process_response({:status, request_ref, status}, state) do
    case Map.fetch!(state.pending_requests, request_ref) do
      {:unary, from, []} ->
        pending_requests = Map.put(state.pending_requests, request_ref, {:unary, from, [status]})
        %{state | pending_requests: pending_requests}

      {:watch, _pid} ->
        state
    end
  end

  defp process_response({:headers, _request_ref, _headers}, state),
    do: state

  defp process_response({:data, request_ref, data}, state) do
    case Map.get(state.pending_requests, request_ref) do
      nil ->
        # This is the case when caller closes the watch stream, but there are messages
        # on the queue to be processed. In this case they are just ignored.
        state

      {:unary, from, response} ->
        pending_requests =
          Map.put(state.pending_requests, request_ref, {:unary, from, response ++ [data]})

        %{state | pending_requests: pending_requests}

      {:watch, pid} ->
        case data do
          %{created: true, watch_id: watch_id} ->
            %{pending: pending} = Map.fetch!(state.watch_streams, request_ref)
            {{:value, from}, pending} = :queue.out_r(pending)
            Connection.reply(from, {:ok, watch_id})
            watch_streams = Map.put(state.watch_streams, request_ref, %{pending: pending})
            %{state | watch_streams: watch_streams}

          %{canceled: true} ->
            %{pending: pending} = Map.fetch!(state.watch_streams, request_ref)
            {{:value, from}, pending} = :queue.out_r(pending)
            Connection.reply(from, :ok)
            watch_streams = Map.put(state.watch_streams, request_ref, %{pending: pending})
            %{state | watch_streams: watch_streams}

          _ ->
            send(pid, {:etcd_watch_response, data})
            state
        end
    end
  end

  defp process_response({:done, request_ref}, state) do
    case Map.fetch!(state.pending_requests, request_ref) do
      {:unary, from, [status | data]} ->
        if status == 200 do
          data
          |> List.first()
          |> case do
            nil -> :ok
            data -> {:ok, data}
          end
          |> then(&Connection.reply(from, &1))
        else
          Connection.reply(from, {:error, {:status, status}})
        end
    end

    pending_requests = Map.delete(state.pending_requests, request_ref)
    %{state | pending_requests: pending_requests}
  end

  defp process_response({:error, request_ref, reason}, state) do
    case Map.fetch!(state.pending_requests, request_ref) do
      {:unary, from, _} ->
        Connection.reply(from, {:error, reason})
        pending_requests = Map.delete(state.pending_requests, request_ref)
        %{state | pending_requests: pending_requests}

      {:watch, pid} ->
        %{pending: pending} = Map.fetch!(state.watch_streams, request_ref)

        for from <- :queue.to_list(pending) do
          Connection.reply(from, {:error, reason})
        end

        send(pid, {:etcd_watch_error, reason})
        pending_requests = Map.delete(state.pending_requests, request_ref)
        watch_streams = Map.delete(state.watch_streams, request_ref)
        %{state | pending_requests: pending_requests, watch_streams: watch_streams}
    end
  end

  defp process_response({:pong, request_ref}, state) do
    keep_alive_timer = KeepAliveTimer.clear_after_timer(state.keep_alive_timer, request_ref)
    %{state | keep_alive_timer: keep_alive_timer}
  end
end

defmodule EtcdEx.Connection do
  @moduledoc """
  Represents a connection to Etcd.
  """

  use GenServer

  @type t :: atom

  @default_eetcd_options []
  @default_eetcd_transport :tcp
  @default_eetcd_transport_opts []

  @doc false
  def get(conn, request), do: GenServer.call(conn, {:get, request}, :infinity)

  @doc false
  def put(conn, request), do: GenServer.call(conn, {:put, request}, :infinity)

  @doc false
  def delete(conn, request), do: GenServer.call(conn, {:delete, request}, :infinity)

  @doc false
  def grant(conn, ttl, request), do: GenServer.call(conn, {:grant, ttl, request}, :infinity)

  @doc false
  def revoke(conn, lease_id, request),
    do: GenServer.call(conn, {:revoke, lease_id, request}, :infinity)

  @doc false
  def keep_alive_once(conn, lease_id),
    do: GenServer.call(conn, {:keep_alive_once, lease_id}, :infinity)

  @doc false
  def ttl(conn, lease_id, with_keys),
    do: GenServer.call(conn, {:ttl, lease_id, with_keys}, :infinity)

  @doc false
  def leases(conn), do: GenServer.call(conn, :leases, :infinity)

  @doc false
  def start_link(options) do
    name =
      case Keyword.fetch(options, :name) do
        {:ok, name} when is_atom(name) ->
          name

        {:ok, other} ->
          raise ArgumentError, "expected :name to be an atom, got: #{inspect(other)}"

        :error ->
          raise ArgumentError, "expected :name option to be present"
      end

    endpoints =
      case Keyword.fetch(options, :endpoints) do
        {:ok, endpoints} when is_list(endpoints) ->
          Enum.map(endpoints, &String.to_charlist/1)

        {:ok, other} ->
          raise ArgumentError,
                "expected :endpoints to be a list of strings, got: #{inspect(other)}"

        :error ->
          ['localhost:2379']
      end

    options = Keyword.get(options, :options, @default_eetcd_options)
    transport = Keyword.get(options, :transport, @default_eetcd_transport)
    transport_opts = Keyword.get(options, :transport_opts, @default_eetcd_transport_opts)

    init_opts = {name, endpoints, options, transport, transport_opts}
    GenServer.start_link(__MODULE__, init_opts, name: name)
  end

  @impl true
  def init({name, endpoints, options, transport, transport_opts}) do
    case :eetcd.open(name, endpoints, options, transport, transport_opts) do
      {:ok, _pid} ->
        {:ok, name}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({method, request}, _from, state) when method in [:get, :put, :delete] do
    result = apply(:eetcd_kv, method, [request])

    {:reply, result, state}
  end

  def handle_call({:grant, ttl, request}, _from, state) do
    result = :eetcd_lease.grant(request, ttl)

    {:reply, result, state}
  end

  def handle_call({:revoke, lease_id, request}, _from, state) do
    result = :eetcd_lease.revoke(request, lease_id)

    {:reply, result, state}
  end

  def handle_call({:keep_alive_once, lease_id}, _from, state) do
    result = :eetcd_lease.keep_alive_once(state, lease_id)

    {:reply, result, state}
  end

  def handle_call({:ttl, lease_id, with_keys}, _from, state) do
    result = :eetcd_lease.time_to_live(state, lease_id, with_keys)

    {:reply, result, state}
  end

  def handle_call(:leases, _from, state) do
    result = :eetcd_lease.leases(state)

    {:reply, result, state}
  end

  @impl true
  def handle_info(_message, state) do
    # XXX: this is required by Gun, as sometimes it keeps sending messages even
    # though the request has already finished (specially on error conditions).
    {:noreply, state}
  end
end

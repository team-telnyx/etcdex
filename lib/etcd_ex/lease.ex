defmodule EtcdEx.Lease do
  @moduledoc """
  This module provides mechanism to set up Etcd leases with limited TTLs
  and keeps them alive.
  """

  use GenServer

  require Logger

  defstruct [:conn, :lease_id, :ttl, :keep_alive]

  @retry_delay :timer.seconds(5)

  @doc """
  Gets the lease maintained by the process.
  """
  @spec get(pid) :: {:ok, any} | :error
  def get(pid) do
    lease_id = GenServer.call(pid, :get)
    {:ok, lease_id}
  catch
    :exit, {:noproc, _} ->
      :error
  end

  @doc """
  Revokes the lease in Etcd and stops the process.
  """
  @spec delete(pid) :: :ok
  def delete(pid) do
    GenServer.call(pid, :delete)
  catch
    :exit, {:noproc, _} ->
      :ok
  end

  @doc """
  Starts process that obtains and maintains a lease in Etcd

  Expects `ttl` and `keep_alive` arguments to be in milliseconds.
  """
  @spec start_link({term, pos_integer, pos_integer}) :: GenServer.on_start()
  def start_link({conn, ttl, keep_alive}) do
    GenServer.start_link(__MODULE__, {conn, ttl, keep_alive})
  end

  @impl true
  def init({conn, ttl, keep_alive}) do
    state = %__MODULE__{
      conn: conn,
      ttl: ttl,
      keep_alive: keep_alive
    }

    {:ok, state, {:continue, :create}}
  end

  @impl true
  def handle_continue(:create, %__MODULE__{conn: conn, ttl: ttl} = state) do
    ttl = :erlang.convert_time_unit(ttl, :millisecond, :second)

    case EtcdEx.grant(conn, ttl) do
      {:ok, %{ID: lease_id}} ->
        state =
          state
          |> Map.put(:lease_id, lease_id)
          |> schedule_keep_alive()

        {:noreply, state}

      {:error, _reason} ->
        {:stop, :shutdown, state}
    end
  end

  @impl true
  def handle_call(:get, _, %__MODULE__{lease_id: lease_id} = state) do
    {:reply, lease_id, state}
  end

  def handle_call(:delete, _, %__MODULE__{conn: conn, lease_id: lease_id} = state) do
    case EtcdEx.revoke(conn, lease_id) do
      {:ok, _} ->
        {:stop, :shutdown, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(:keep_alive, %__MODULE__{conn: conn, lease_id: lease_id} = state) do
    case keep_alive(conn, lease_id) do
      {:ok, _} ->
        state = schedule_keep_alive(state)
        {:noreply, state}

      {:error, :not_found} ->
        {:stop, :shutdown, state}

      {:error, _reason} ->
        # extending the ttl failed but the lease is still alive, so keep running
        state = schedule_keep_alive(state)
        {:noreply, state}
    end
  end

  defp keep_alive(conn, lease_id) do
    with {:ok, %{TTL: ttl}} when ttl > 0 <- EtcdEx.ttl(conn, lease_id, keys: false),
         {:ok, _} <- EtcdEx.keep_alive(conn, lease_id) do
      {:ok, lease_id}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :not_found}
    end
  end

  defp schedule_keep_alive(state) do
    Process.send_after(self(), :keep_alive, next_tick(state))
    state
  end

  defp next_tick(%__MODULE__{lease_id: nil}), do: @retry_delay
  defp next_tick(%__MODULE__{keep_alive: keep_alive}), do: keep_alive
end

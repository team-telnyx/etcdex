defmodule EtcdEx.Watch do
  @moduledoc """
  Represents an Etcd watch.
  """

  use GenServer

  require Logger

  defstruct [:watcher, :conn, :watch_conn]

  @unwatch_timeout :timer.seconds(5)

  @doc false
  def watch(pid, request), do: GenServer.call(pid, {:watch, request}, :infinity)

  @doc false
  def cancel(pid), do: GenServer.stop(pid)

  @doc false
  def start_link(init_opts), do: GenServer.start_link(__MODULE__, init_opts)

  @impl true
  def init({watcher, name}) do
    Process.flag(:trap_exit, true)

    {:ok, %__MODULE__{watcher: watcher, conn: name}}
  end

  @impl true
  def handle_call({:watch, request}, {watcher, _tag}, %{watcher: watcher} = state) do
    %{conn: name, watch_conn: watch_conn} = state

    result =
      case watch_conn do
        nil -> :eetcd_watch.watch(name, request)
        _ -> :eetcd_watch.watch(name, request, watch_conn)
      end

    case result do
      {:ok, watch_conn, watch_id} ->
        {:reply, {:ok, watch_id}, %{state | watch_conn: watch_conn}}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(_, _from, state), do: {:reply, {:error, :not_on_controlling_process}, state}

  @impl true
  def terminate(_reason, state) do
    %{watch_conn: watch_conn} = state

    unless watch_conn == nil do
      :eetcd_watch.unwatch(watch_conn, @unwatch_timeout)
    end
  end

  @impl true
  def handle_info(_message, %{watch_conn: nil} = state), do: {:noreply, state}

  def handle_info(message, state) do
    %{watch_conn: watch_conn} = state

    case :eetcd_watch.watch_stream(watch_conn, message) do
      {:more, watch_conn} ->
        {:noreply, %{state | watch_conn: watch_conn}}

      {:ok, watch_conn, response} ->
        %{watcher: watcher} = state

        send(watcher, {:etcd_watch_response, response})

        {:noreply, %{state | watch_conn: watch_conn}}

      :unknown ->
        # Parent process probably died (message isn't for eetcd)
        {:noreply, state}

      {:error, reason} ->
        Logger.warn("Error while watching Etcd stream: #{inspect(reason)}")

        {:noreply, state}
    end
  end
end

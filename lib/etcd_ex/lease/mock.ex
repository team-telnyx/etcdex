defmodule EtcdEx.Lease.Mock do
  @moduledoc false
  use GenServer

  def start_link({_, _, _}), do: GenServer.start_link(__MODULE__, nil)
  def get(_), do: {:ok, 666}
  def delete(pid), do: GenServer.stop(pid)
  def init(_), do: {:ok, nil}
end

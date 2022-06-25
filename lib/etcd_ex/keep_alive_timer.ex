defmodule EtcdEx.KeepAliveTimer do
  @moduledoc false

  # gRPC keep-alive is just HTTP2 keep-alive: send PING frames every interval
  # after receiving some data and wait at most timeout before saying the
  # connection is severed

  defstruct [:interval_timer, :interval, :timeout, timeout_timers: %{}]

  @default_keep_alive_interval :timer.seconds(10)
  @default_keep_alive_timeout :timer.seconds(20)

  def start(options) do
    interval = Keyword.get(options, :keep_alive_interval, @default_keep_alive_interval)
    timeout = Keyword.get(options, :keep_alive_timeout, @default_keep_alive_timeout)

    %__MODULE__{
      interval_timer: start_interval_timer(interval),
      interval: interval,
      timeout: timeout
    }
  end

  def reset_interval_timer(%__MODULE__{} = keep_alive_timer) do
    cancel_timer(keep_alive_timer.interval_timer)

    %{keep_alive_timer | interval_timer: start_interval_timer(keep_alive_timer.interval)}
  end

  def start_timeout_timer(%__MODULE__{} = keep_alive_timer, request_ref) do
    put_in(
      keep_alive_timer.timeout_timers[request_ref],
      Process.send_after(self(), :keep_alive_expired, keep_alive_timer.timeout)
    )
  end

  def clear_after_timer(%__MODULE__{} = keep_alive_timer, request_ref) do
    {timeout_timer, keep_alive_timer} = pop_in(keep_alive_timer.timeout_timers[request_ref])

    cancel_timer(timeout_timer)

    keep_alive_timer
  end

  defp start_interval_timer(interval) do
    Process.send_after(self(), :keep_alive, interval)
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer), do: Process.cancel_timer(timer)
end

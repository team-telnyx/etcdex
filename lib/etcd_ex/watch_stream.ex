defmodule EtcdEx.WatchStream do
  @moduledoc false

  alias EtcdEx.Types

  require Logger

  @type watch_ref :: reference

  @opaque t() :: %__MODULE__{}

  defstruct pending_reqs: :queue.new(), watches: %{}, watch_ids: %{}

  @doc false
  @spec new() :: t
  def new(), do: %__MODULE__{}

  @doc false
  @spec watch(EtcdEx.Mint.t(), Mint.Types.request_ref(), t, Types.key(), [Types.watch_opt()]) ::
          {:ok, EtcdEx.Mint.t(), t, watch_ref}
          | {:error, EtcdEx.Mint.t(), Mint.Types.error()}
  def watch(env, request_ref, watch_stream, key, opts \\ []) do
    %{pending_reqs: pending_reqs, watches: watches} = watch_stream

    watch_ref = make_ref()

    watches =
      Map.put(watches, watch_ref, %{
        watch_id: nil,
        key: key,
        opts: opts,
        events: []
      })

    watch_stream = %{
      watch_stream
      | pending_reqs: :queue.in(watch_ref, pending_reqs),
        watches: watches
    }

    result =
      if :queue.is_empty(pending_reqs) do
        EtcdEx.Mint.watch(env, request_ref, key, opts)
      else
        {:ok, env}
      end

    case result do
      {:ok, env} -> {:ok, env, watch_stream, watch_ref}
      error -> error
    end
  end

  @doc false
  @spec cancel_watch(EtcdEx.Mint.t(), Mint.Types.request_ref(), t, watch_ref) ::
          {:ok, EtcdEx.Mint.t()}
          | {:error, EtcdEx.Mint.t(), Mint.Types.error()}
  def cancel_watch(env, request_ref, watch_stream, watch_ref) do
    case Map.get(watch_stream.watches, watch_ref) do
      nil ->
        {:error, env, :not_found}

      %{watch_id: nil} ->
        {:error, env, :pending}

      %{watch_id: watch_id} ->
        EtcdEx.Mint.cancel_watch(env, request_ref, watch_id)
    end
  end

  @doc false
  @spec stream(EtcdEx.Mint.t(), Mint.Types.request_ref(), t, Types.response()) ::
          {:ok, EtcdEx.Mint.t(), t,
           :empty
           | {:etcd_watch_created, watch_ref}
           | {:etcd_watch_notify, watch_ref, EtcdEx.Proto.WatchResponse}
           | {:etcd_watch_notify_progress, EtcdEx.Proto.WatchResponse}
           | {:etcd_watch_canceled, watch_ref, reason :: any}}
          | {:error, EtcdEx.Mint.t(), reason :: any}
  def stream(env, request_ref, watch_stream, response) when request_ref == elem(response, 1) do
    case response do
      {:status, _request_ref, _status} ->
        {:ok, env, watch_stream, :empty}

      {:headers, _request_ref, _headers} ->
        {:ok, env, watch_stream, :empty}

      {:data, _request_ref, data} ->
        stream_data(env, request_ref, watch_stream, data)

      {:done, _request_ref} ->
        {:error, env, :closed}
    end
  end

  defp stream_data(env, request_ref, watch_stream, %{created: true, watch_id: watch_id}) do
    %{pending_reqs: pending_reqs, watches: watches, watch_ids: watch_ids} = watch_stream

    case :queue.out(pending_reqs) do
      {:empty, _} ->
        {:error, env, :bad_ref}

      {{:value, watch_ref}, pending_reqs} ->
        watches = Map.update!(watches, watch_ref, &%{&1 | watch_id: watch_id})
        watch_ids = Map.put(watch_ids, watch_id, watch_ref)

        watch_stream = %{
          watch_stream
          | pending_reqs: pending_reqs,
            watches: watches,
            watch_ids: watch_ids
        }

        result =
          case :queue.peek(pending_reqs) do
            :empty ->
              {:ok, env}

            {:value, next_watch_ref} ->
              %{key: key, opts: opts} = Map.fetch!(watches, next_watch_ref)
              EtcdEx.Mint.watch(env, request_ref, key, opts)
          end

        case result do
          {:ok, env} -> {:ok, env, watch_stream, {:etcd_watch_created, watch_ref}}
          error -> error
        end
    end
  end

  defp stream_data(
         env,
         request_ref,
         watch_stream,
         %{
           canceled: true,
           watch_id: watch_id
         } = data
       ) do
    %{watches: watches, watch_ids: watch_ids} = watch_stream

    case Map.get(watch_ids, watch_id) do
      nil ->
        {:error, env, :bad_ref}

      watch_ref ->
        watches = Map.delete(watches, watch_ref)
        watch_ids = Map.delete(watch_ids, watch_id)
        watch_stream = %{watch_stream | watches: watches, watch_ids: watch_ids}

        env =
          if Enum.empty?(watch_ids) do
            case EtcdEx.Mint.cancel_request(env, request_ref) do
              {:ok, env} -> env
              {:error, env, _reason} -> env
            end
          else
            env
          end

        reason =
          case data do
            %{compact_revision: rev} when rev > 0 -> {:compacted, rev}
            %{cancel_reason: reason} -> reason
          end

        {:ok, env, watch_stream, {:etcd_watch_canceled, watch_ref, reason}}
    end
  end

  defp stream_data(env, _request_ref, watch_stream, %{
         fragment: true,
         events: events,
         watch_id: watch_id
       }) do
    %{watches: watches, watch_ids: watch_ids} = watch_stream

    case Map.get(watch_ids, watch_id) do
      nil ->
        {:error, env, :bad_ref}

      watch_ref ->
        watches = Map.update!(watches, watch_ref, &%{&1 | events: &1.events ++ events})
        {:ok, env, %{watch_stream | watches: watches}, :empty}
    end
  end

  defp stream_data(
         env,
         request_ref,
         watch_stream,
         %{events: events, watch_id: watch_id} = watch_response
       ) do
    %{watches: watches, watch_ids: watch_ids} = watch_stream

    case Map.get(watch_ids, watch_id) do
      nil ->
        # watch response on unexpected watch id; cancel id.
        # https://github.com/etcd-io/etcd/blob/68b1e9f728ba1d0a823a96efe1e9b58dc1d42eb6/client/v3/watch.go#L628
        case EtcdEx.Mint.cancel_watch(env, request_ref, watch_id) do
          {:ok, env} -> {:ok, env, watch_stream, :empty}
          error -> error
        end

      -1 ->
        # watch IDs are zero indexed, so request notify watch responses are assigned a watch ID of -1 to
        # indicate they should be broadcasted.
        # https://github.com/etcd-io/etcd/blob/68b1e9f728ba1d0a823a96efe1e9b58dc1d42eb6/client/v3/watch.go#L719
        {:ok, env, watch_stream, {:etcd_watch_notify_progress, watch_response}}

      watch_ref ->
        %{events: pending_events, opts: opts} = Map.fetch!(watches, watch_ref)
        opts = Keyword.put(opts, :start_revision, watch_response.header.revision + 1)
        watches = Map.update!(watches, watch_ref, &%{&1 | events: [], opts: opts})
        watch_response = %{watch_response | events: pending_events ++ events}

        {:ok, env, %{watch_stream | watches: watches},
         {:etcd_watch_notify, watch_ref, watch_response}}
    end
  end

  @doc false
  def reconnect(env, request_ref, watch_stream) do
    %{watches: watches} = watch_stream

    {pending_reqs, watches} =
      watches
      |> Map.keys()
      |> Enum.reduce({:queue.new(), watches}, fn
        watch_ref, {pending_reqs, watches} ->
          watches = Map.update!(watches, watch_ref, &%{&1 | events: [], watch_id: nil})
          pending_reqs = :queue.in(watch_ref, pending_reqs)
          {pending_reqs, watches}
      end)

    watch_stream = %{watch_stream | pending_reqs: pending_reqs, watches: watches, watch_ids: %{}}

    case :queue.peek(pending_reqs) do
      :empty ->
        {env, watch_stream}

      {:value, watch_ref} ->
        %{key: key, opts: opts} = Map.fetch!(watches, watch_ref)

        case EtcdEx.Mint.watch(env, request_ref, key, opts) do
          {:ok, env} ->
            {env, watch_stream}

          {:error, env, reason} ->
            Logger.warn("error while reconnecting watches: #{inspect(reason)}")
            {env, watch_stream}
        end
    end
  end
end

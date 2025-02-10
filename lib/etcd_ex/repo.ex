defmodule EtcdEx.Repo do
  @moduledoc """
  Provides a repository for reading and writing data to etcd.
  """

  use Supervisor

  @impl true
  def init(opts) do
    {conn_opts, cache_opts} = Keyword.split(opts, [:endpoint])
    module = cache_opts[:module]
    conn_opts = Keyword.put(conn_opts, :name, module.conn_name())

    children = [
      {EtcdEx, conn_opts},
      {__MODULE__.Cache, cache_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc false
  defmacro __using__(opts) do
    {otp_app, prefix, pubsub, static_opts} = compile_opts(opts)

    # credo:disable-for-next-line
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      @default_endpoint {:http, "localhost", 2379, []}
      @default_bootstrap_timeout 5_000
      @default_bootstrap_backoff 5_000

      @prefix unquote(prefix)
      @pubsub unquote(pubsub)

      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      @doc """
      Starts repo.
      """
      def start_link(runtime_opts) do
        default_opts = [
          module: __MODULE__,
          endpoint: @default_endpoint,
          bootstrap_timeout: @default_bootstrap_timeout,
          bootstrap_backoff: @default_bootstrap_backoff
        ]

        static_opts =
          unquote(static_opts)
          |> Keyword.take([:bootstrap_timeout, :bootstrap_backoff])
          |> Keyword.merge(
            prefix: @prefix,
            pubsub: @pubsub
          )

        application_opts =
          if unquote(otp_app) do
            unquote(otp_app)
            |> Application.fetch_env!(__MODULE__)
            |> Keyword.take([:endpoint, :bootstrap_timeout, :bootstrap_backoff])
          else
            []
          end

        runtime_opts =
          runtime_opts
          |> Keyword.take([:endpoint, :bootstrap_timeout, :bootstrap_backoff])

        opts =
          default_opts
          |> Keyword.merge(static_opts)
          |> Keyword.merge(application_opts)
          |> Keyword.merge(runtime_opts)

        Supervisor.start_link(unquote(__MODULE__), opts, name: __MODULE__)
      end

      @doc false
      def conn_name, do: Module.concat(__MODULE__, Connection)

      @doc false
      def cache_name, do: Module.concat(__MODULE__, Cache)

      @doc """
      Returns connection process.
      """
      def conn do
        Process.whereis(conn_name())
      end

      @doc """
      Returns etcd key prefix.
      """
      @spec prefix :: String.t()
      def prefix, do: @prefix

      @doc """
      Select cached data with ets match spec.
      """
      @spec select(:ets.match_spec()) :: list(term)
      def select(match_spec \\ [{:_, [], [:"$_"]}]) do
        :ets.select(cache_name(), match_spec)
      end

      @doc """
      Retrieves cached value.
      """
      @spec get(term) :: term
      def get(key) do
        case :ets.lookup(cache_name(), key) do
          [] -> nil
          [{_key, value}] -> value
        end
      end

      @doc """
      Puts key/value pair into etcd.
      """
      @spec put(term, term, keyword) :: {:ok, term} | {:error, term}
      def put(key, value, opts \\ []) do
        GenServer.call(cache_name(), {:put, key, value, opts})
      end

      @doc """
      Deletes key/value pair from etcd.
      """
      @spec delete(term, keyword) :: {:ok, term} | {:error, term}
      def delete(key, opts \\ []) do
        GenServer.call(cache_name(), {:delete, key, opts})
      end

      if @pubsub do
        @doc """
        Subscribes to updates for all keys.

        If the caller also subscribes to updates for specific key using
        `subscribe/1`, it will receive duplicate messages for that key.
        """
        @spec subscribe :: :ok | {:error, term}
        def subscribe do
          Phoenix.PubSub.subscribe(@pubsub, unquote(__MODULE__).pubsub_topic(__MODULE__))
        end

        @doc """
        Subscribes to updates for single key.
        """
        @spec subscribe(term) :: :ok | {:error, term}
        def subscribe(key) do
          Phoenix.PubSub.subscribe(
            @pubsub,
            unquote(__MODULE__).pubsub_topic(key, __MODULE__, @prefix)
          )
        end

        @doc """
        Unsubscribes from updates for all keys.

        If the caller also subscribed to updates for specific key using
        `subscribe/1`, it will need to unsubscribe using `unsubscribe/1`
        in order to stop receiving updates for that key.
        """
        @spec unsubscribe :: :ok
        def unsubscribe do
          Phoenix.PubSub.unsubscribe(@pubsub, unquote(__MODULE__).pubsub_topic(__MODULE__))
        end

        @doc """
        Unsubscribes from updates for single key.
        """
        @spec unsubscribe(term) :: :ok
        def unsubscribe(key) do
          Phoenix.PubSub.unsubscribe(
            @pubsub,
            unquote(__MODULE__).pubsub_topic(key, __MODULE__, @prefix)
          )
        end
      end

      @impl true
      def decode_key(key, prefix) do
        key = String.replace_leading(key, prefix, "")
        {:ok, key}
      end

      @impl true
      def encode_key(key, prefix) when is_binary(key) do
        prefix <> key
      end

      @impl true
      def decode_value(_key, value) do
        Jason.decode(value)
      end

      @impl true
      def encode_value(_key, value) do
        Jason.encode!(value)
      end

      @impl true
      def bootstrap_from_static_data do
        {:ok, []}
      end

      defoverridable unquote(__MODULE__)
    end
  end

  @doc """
  Converts etcd key to a more convenient term for local use.

  This term is used to reference the object when retrieving from cache,
  writing into etcd and broadcasting changes.

  If decoding fails (function returns `:error` tuple), key/value pair is
  ignored. This is to prevent situations when a badly formatted key read from
  etcd unexpectedly crashes the process.

  If the tuple is `{:error, :ignore}` the key/value pair is quietly ignored.
  If the tuple is `{:error, reason}` the key/value pair is ignored and the reason is logged.

  Default implementation simply removes the prefix from the key.
  """
  @callback decode_key(key :: String.t(), prefix :: String.t()) :: {:ok, term} | {:error, term}

  @doc """
  Converts term back to etcd key.

  It is required that this function does the exact reverse of `decode_key`
  in order for change broadcasting to work.

  Default implementation simply adds the prefix back.
  """
  @callback encode_key(key :: term, prefix :: String.t()) :: String.t()

  @doc """
  Decodes value after reading from etcd.

  If decoding fails (function returns `:error` tuple), key/value pair is
  ignored. This is to prevent situations when a badly formatted value read from
  etcd unexpectedly crashes the process.

  Default implementation uses Jason.decode/1.
  """
  @callback decode_value(key :: term, value :: term) :: {:ok, term} | {:error, term}

  @doc """
  Encodes value before writing into etcd.

  Default implementation uses Jason.encode!/1
  """
  @callback encode_value(key :: term, value :: term) :: term

  @doc """
  Bootstraps from static data.

  When bootstrap from etcd fails, we can fall back to static data to populate the cache
  and continue to serve read requests. In the meantime we will keep trying to bootstrap
  from etcd in the background. The repo will remain in read-only mode until the bootstrap
  is successful.

  This function should return an :ok tuple with the list of %{key: key, value: value} maps
  to be inserted into the cache, or an :error.
  """
  @callback bootstrap_from_static_data() :: {:ok, [%{key: term, value: term}]} | :error

  defp compile_opts(opts) do
    otp_app =
      case Keyword.fetch(opts, :otp_app) do
        {:ok, otp_app} when is_atom(otp_app) ->
          otp_app

        {:ok, other} ->
          raise ArgumentError, "expected :otp_app to be atom, got: #{inspect(other)}"

        :error ->
          nil
      end

    prefix =
      case Keyword.fetch(opts, :prefix) do
        {:ok, prefix} when is_binary(prefix) ->
          prefix

        {:ok, other} ->
          raise ArgumentError, "expected :prefix to be string, got: #{inspect(other)}"

        :error ->
          raise ArgumentError, "expected :prefix to be present"
      end

    pubsub =
      with {:ok, pubsub} <- Keyword.fetch(opts, :pubsub),
           {:module, _} <- Code.ensure_loaded(Phoenix.PubSub) do
        pubsub
      else
        {:error, _reason} ->
          raise ArgumentError, "using :pubsub requires phoenix_pubsub dependency"

        :error ->
          nil
      end

    opts = Keyword.drop(opts, [:otp_app, :prefix, :pubsub])

    {otp_app, prefix, pubsub, opts}
  end

  @doc false
  def pubsub_topic(module) do
    "#{module}"
  end

  @doc false
  def pubsub_topic(key, module, prefix) do
    "#{module}:#{module.encode_key(key, prefix)}"
  end
end

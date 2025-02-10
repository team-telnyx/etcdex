defmodule EtcdEx.Repo.Mock do
  @moduledoc """
  Repository mock for testing.

  Use in your test module to setup a mock cache for your repository.

      defmodule MyTest do
        use ExUnit.Case
        use EtcdEx.Repo.Mock

        setup do
          mock_repo(MyRepo, [
            %{key: "/foo", value: "1"},
          ])
        end
      end

  Make sure your repository mock includes key-vaule pairs, where values are
  JSON-encoded.
  """

  defmacro __using__(_) do
    quote location: :keep do
      def mock_repo(module, kvs) do
        start_supervised(%{
          id: __MODULE__.RepoMocks,
          start: {Agent, :start_link, [fn -> %{} end, [name: __MODULE__.RepoMocks]]}
        })

        Mimic.set_mimic_global()

        prefix = module.prefix()
        test_pid = self()
        ref = make_ref()

        Agent.update(__MODULE__.RepoMocks, fn mocks ->
          Map.put(mocks, prefix, {module, nil, test_pid, ref, 1})
        end)

        # etcd watch
        Mimic.stub(
          EtcdEx,
          :watch,
          fn _, _, prefix, [{:prefix, true} | _] ->
            {test_pid, ref} =
              Agent.get(__MODULE__.RepoMocks, fn %{^prefix => {_, _, test_pid, ref, _}} ->
                {test_pid, ref}
              end)

            send(test_pid, {:etcd_watch, prefix, ref})
            {:ok, ref}
          end
        )

        # bootstrap data
        Mimic.stub(
          EtcdEx,
          :get,
          fn _, prefix, [prefix: true], _timeout ->
            module =
              Agent.get(__MODULE__.RepoMocks, fn %{^prefix => {module, _, _, _, _}} ->
                module
              end)

            {:ok,
             %{
               header: %{revision: next_etcd_revision(module)},
               kvs: List.flatten(kvs)
             }}
          end
        )

        # start cache process
        {:ok, pid} = start_supervised(module)

        Agent.update(__MODULE__.RepoMocks, fn mocks ->
          Map.update!(mocks, prefix, fn {module, _, test_pid, ref, revision} ->
            {module, pid, test_pid, ref, revision}
          end)
        end)

        # allow time to bootstrap
        :timer.sleep(50)

        # stub updates
        Mimic.stub(
          EtcdEx,
          :put,
          fn _, key, value, opts ->
            {module, test_pid} =
              Agent.get(__MODULE__.RepoMocks, fn mocks ->
                Enum.find_value(mocks, fn
                  {prefix, {module, _, test_pid, _, _}} ->
                    if String.starts_with?(key, prefix) do
                      {module, test_pid}
                    end

                  _ ->
                    false
                end)
              end)

            send(test_pid, {:etcd_put, key, value, opts})
            etcd_notify(module, [%{type: :PUT, kv: %{key: key, value: value}}])

            {:ok,
             %{header: %{revision: next_etcd_revision(module)}, kvs: [%{key: key, value: value}]}}
          end
        )

        Mimic.stub(
          EtcdEx,
          :delete,
          fn _, key, _ ->
            {module, test_pid} =
              Agent.get(__MODULE__.RepoMocks, fn mocks ->
                Enum.find_value(mocks, fn
                  {prefix, {module, _, test_pid, _, _}} ->
                    if String.starts_with?(key, prefix) do
                      {module, test_pid}
                    end

                  _ ->
                    false
                end)
              end)

            send(test_pid, {:etcd_delete, key})
            etcd_notify(module, [%{type: :DELETE, kv: %{key: key}}])
            {:ok, %{header: %{revision: next_etcd_revision(module)}, kvs: [%{key: key}]}}
          end
        )

        :ok
      end

      def etcd_notify(module, events) do
        ref =
          Agent.get(__MODULE__.RepoMocks, fn mocks ->
            Enum.find_value(mocks, fn
              {prefix, {^module, _, _, ref, _}} -> ref
              _ -> false
            end)
          end)

        send(
          module.cache_name(),
          {:etcd_watch_notify, ref,
           %{events: events, header: %{revision: next_etcd_revision(module)}}}
        )

        # allow time to process events
        :timer.sleep(50)
      end

      def next_etcd_revision(module) do
        Agent.get_and_update(__MODULE__.RepoMocks, fn mocks ->
          {prefix, {module, pid, test_pid, ref, revision}} =
            Enum.find_value(mocks, fn
              {prefix, {^module, _, _, _, _} = mock} -> {prefix, mock}
              _ -> false
            end)

          {revision, Map.put(mocks, prefix, {module, pid, test_pid, ref, revision + 1})}
        end)
      end
    end
  end
end

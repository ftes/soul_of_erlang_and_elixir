defmodule MySystem.BulletinBoard do
  @moduledoc false
  use Parent.Supervisor

  alias :mnesia, as: Mnesia

  require Logger

  @attributes [:id, :timestamp, :author, :text, :topic]

  def start_link(_arg) do
    Mnesia.create_schema([node()])
    Mnesia.start()
    ensure_tables_exist()
    Parent.Supervisor.start_link([], name: __MODULE__)
  end

  def publish_post(author, text, topic) do
    caller = self()

    {:ok, pid} =
      Parent.Client.start_child(
        __MODULE__,
        %{
          start: {Task, :start_link, [fn -> :ok = save_post(author, text, topic) end]},
          restart: :temporary,
          ephemeral?: true,
          meta: caller
        }
      )

    Process.monitor(pid)
    pid
  end

  def list_posts(topic) do
    fn ->
      Mnesia.select(Post, [
        {
          {Post, :"$1", :"$2", :"$3", :"$4", :"$5"},
          [
            {:"=:=", :"$5", topic}
          ],
          [:"$$"]
        }
      ])
    end
    |> Mnesia.transaction()
    |> unwrap_atomic()
    |> result_to_map()
  end

  def subscribe(topic) do
    Phoenix.PubSub.subscribe(MySystem.PubSub, topic)
  end

  def delete_post(topic, id) do
    fn ->
      Mnesia.delete({Post, id})
    end
    |> Mnesia.transaction()
    |> unwrap_atomic()
    |> maybe_notify_subscribers(topic, :deleted_post, %{id: id})
  end

  def save_post(author, text, topic) do
    id = Mnesia.dirty_update_counter(Counter, Post, 1)

    fn ->
      Mnesia.write({Post, id, DateTime.utc_now(), author, text, topic})
    end
    |> Mnesia.transaction()
    |> unwrap_atomic()
    |> maybe_notify_subscribers(topic, :new_post, %{id: id, text: text, author: author})
  end

  def reset do
    Mnesia.delete_table(Post)
    ensure_tables_exist()
  end

  defp ensure_tables_exist do
    status =
      Mnesia.create_table(Counter,
        attributes: [:table, :counter],
        type: :set,
        disc_copies: [node()]
      )

    case status do
      {:atomic, :ok} ->
        Logger.info("Table Counter successfully created")

      {:aborted, {:already_exists, Counter}} ->
        Logger.info("Table Counter already exists")

      other ->
        Logger.error("Could not create Counter table, reason #{inspect(other)}")
    end

    status =
      Mnesia.create_table(Post,
        attributes: @attributes,
        type: :ordered_set,
        disc_copies: [node()]
      )

    case status do
      {:atomic, :ok} ->
        Logger.info("Table Post successfully created")

      {:aborted, {:already_exists, Post}} ->
        Logger.info("Table Post already exists")

      other ->
        Logger.error("Could not create Post table, reason #{inspect(other)}")
    end
  end

  defp unwrap_atomic({:atomic, :ok}), do: :ok
  defp unwrap_atomic({:atomic, result}), do: {:ok, result}
  defp unwrap_atomic({:aborted, reason}), do: {:error, reason}

  defp result_to_map({:ok, result}) do
    {:ok,
     Enum.map(result, fn post ->
       @attributes
       |> Enum.zip(post)
       |> Map.new()
     end)}
  end

  defp maybe_notify_subscribers(:ok, topic, event, payload) do
    Phoenix.PubSub.broadcast!(MySystem.PubSub, topic, {event, payload})
  end

  defp maybe_notify_subscribers(error, _, _, _), do: error
end

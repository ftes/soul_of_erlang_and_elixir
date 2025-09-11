defmodule MySystem.BulletinBoard do

  require Logger

  alias :mnesia, as: Mnesia

  def start() do
    Mnesia.create_schema([node()])
    Mnesia.start()
    ensure_tables_exist()
  end


  def publish_post(author, text, topic) do
    id = Mnesia.dirty_update_counter(Counter, Post, 1)
    Mnesia.transaction(fn ->
      Mnesia.write({Post, id, DateTime.utc_now(), author, text, topic})
    end)
    |> unwrap_atomic()
  end


  def list_posts(topic, start_id, pagesize \\ 100) do
    Mnesia.transaction(fn ->
      Mnesia.select(Post, [{
        {Post, :"$1", :"$2", :"$3", :"$4", :"$5"},
        [
          {:>, :"$1", start_id},
          {:<, :"$1", start_id + pagesize},
          {:"=:=", :"$5", topic}],
        [:"$$"]
      }])
    end)
    |> unwrap_atomic()
  end


  defp ensure_tables_exist() do
    status = Mnesia.create_table(Counter,
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

    status = Mnesia.create_table(Post,
      attributes: [:id, :timestamp, :author, :text, :topic],
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

end

defmodule MySystemWeb.BulletinBoard do
  use MySystemWeb, :live_view

  @buildingblocks "buildingblocks"
  @observability "observability"

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket
          |> assign(:author, "")
          |> assign(:text, "")}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"topic" => topic}, _uri, socket) do
    if topic == @buildingblocks or topic == @observability do
      :ok = MySystem.BulletinBoard.subscribe(topic)
      socket
      |> make_long_topic_title(topic)
      |> load_posts(topic)
    else
      # redirect to default if invalid
      push_navigate(socket, to: ~p"/bulletin_board/buildingblocks") |> then(&{:noreply, &1})
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <h1 class="text-3xl">{@long_topic}</h1>
      <form class="p-4 bg-slate-200 rounded-lg" phx-submit="post_submitted">
        <textarea class="block" name="text" rows="10" cols="100">{@text} </textarea>
        <input class="mt-2 block" type="text" name="author" value={@author} />
      </form>
      <ul class="flex flex-col gap-2 mt-4">
        <%= for post <- @posts do %>
          <li class="bg-slate-200 p-4 rounded-lg">
            <p class="text-xl">{post.text}</p>
            <div class="text-right">{post.author}</div>
          </li>
        <% end %>
      </ul>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("post_submitted", params, socket) do
    author = Map.get(params, "author", "")
    text = Map.get(params, "text", "")
    if (author != "" and text != "") do
      topic = Map.fetch!(socket.assigns, :topic)
      _pid = MySystem.BulletinBoard.publish_post(author, text, topic)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_post, _id}, socket) do
    load_posts(socket, Map.fetch!(socket.assigns, :topic))
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    if reason != :normal do
      {:noreply, put_flash(socket, :error, "Posting of Message failed.")}
    else
    # TODO: inspect reason and put a flash message when postin failed
      {:noreply, socket}
    end
  end

  defp make_long_topic_title(socket, @buildingblocks) do
    socket
    |> assign(:long_topic, "What are your building blocks for robust systems?")
  end

  defp make_long_topic_title(socket, @observability) do
    socket
    |> assign(:long_topic, "How do you find a misbehaving part of your software?")
  end

  defp load_posts(socket, topic) do
    {:ok, posts} = MySystem.BulletinBoard.list_posts(topic, 0, 100)
    {:noreply, socket
               |> assign(:text, "")
               |> assign(:topic, topic)
               |> assign(:posts, posts)}
  end

end

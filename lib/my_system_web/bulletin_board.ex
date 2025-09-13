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
      load_posts(socket, topic)
    else
      # redirect to default if invalid
      push_navigate(socket, to: ~p"/bulletin_board/buildingblocks") |> then(&{:noreply, &1})
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
      <h1>Topic: {@topic}</h1>
        <form phx-submit="post_submitted">
          <textarea name="text" rows="10" cols="50">{@text} </textarea>
          <input type="text" name="author" value={@author} />
        </form>
      <ul>
        <%= for post <- @posts do %>
          <li>
            <p>{post.text}</p>
            <div>{post.author}</div>
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
      :ok = MySystem.BulletinBoard.publish_post(author, text, topic)
      # TODO: Perform publish in a separate process and fire PubSub on Success
      # TODO: Reload Posts on PubSub Message
      load_posts(socket, topic)
    else
      {:noreply, socket}
    end
  end

  defp load_posts(socket, topic) do
    {:ok, posts} = MySystem.BulletinBoard.list_posts(topic, 0, 100)
    {:noreply, socket
               |> assign(:text, "")
               |> assign(:topic, topic)
               |> assign(:posts, posts)}
  end

end

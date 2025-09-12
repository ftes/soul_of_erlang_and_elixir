defmodule MySystemWeb.BulletinBoard do
  use MySystemWeb, :live_view

  @buildingblocks "buildingblocks"
  @observability "observability"

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket = assign(socket, number: "", operations: [])
    {:ok, socket}
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
  def handle_event("submit_post", _params, socket) do
    {:noreply, socket}
  end

  defp load_posts(socket, topic) do
    {:ok, posts} = MySystem.BulletinBoard.list_posts(topic, 0, 100)
    {:noreply, socket
               |> assign(:topic, topic)
               |> assign(:posts, posts)}
  end

end

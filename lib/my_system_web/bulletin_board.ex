defmodule MySystemWeb.BulletinBoard do
  use MySystemWeb, :live_view

  @buildingblocks "building-blocks"
  @observability "observability"
  @pubsub_topic "bulletin-boards"

  defguardp is_admin(socket) when socket.assigns.admin? == true

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Board")
    |> assign(:form, to_form(%{}, as: :post))
    |> assign(:show_form, true)
    |> assign(:admin?, socket.assigns.live_action == :admin)
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_params(%{"topic" => topic}, _uri, socket)
      when topic in [@buildingblocks, @observability] do
    :ok = MySystem.BulletinBoard.subscribe(topic)
    :ok = Phoenix.PubSub.subscribe(MySystem.PubSub, @pubsub_topic)

    socket
    |> assign(:topic, topic)
    |> assign(:topics, [@buildingblocks, @observability])
    |> load_posts()
    |> noreply()
  end

  def handle_params(_params, _uri, socket) do
    topic = Application.fetch_env!(:my_system, :bulletin_board)
    push_navigate(socket, to: ~p"/board/#{topic}") |> noreply()
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>{long_topic(@topic)}</.header>
      <form :if={@admin?} phx-change="change">
        <select name="topic" class="text-base-100 hover:cursor-pointer">
          <option :for={topic <- @topics} selected={topic == @topic} value={topic}>
            {topic}
          </option>
        </select>
      </form>
      <div :if={not @admin?} class="p-4 bg-base-300 rounded-lg">
        <button phx-click={
          JS.toggle(to: "#form") |> JS.toggle_class("rotate-180", to: "#toggle-form-icon")
        }>
          <.icon id="toggle-form-icon" name="hero-chevron-up" class="size-5" />
        </button>
        <.form for={@form} id="form" class="mt-4" phx-change="validate" phx-submit="submit">
          <div class="block">
            <.input
              sr_label="Text"
              placeholder="Your post"
              field={@form[:text]}
              type="textarea"
              phx-debounce
              rows="10"
              cols="80"
            />
          </div>
          <div class="mt-2 block">
            <.input
              sr_label="Author"
              placeholder="Your name"
              field={@form[:author]}
              id="author"
              phx-hook=".PreserveAuthor"
              phx-debounce
            />
            <script :type={Phoenix.LiveView.ColocatedHook} name=".PreserveAuthor">
              export default {
                mounted() {
                  this.readFromLocalStorage()
                  this.el.addEventListener('input', (e) => {
                    localStorage.setItem('author', e.target.value)
                  })
                },

                updated() {
                  this.readFromLocalStorage()
                },

                readFromLocalStorage() {
                  const savedAuthor = localStorage.getItem('author')
                  if (savedAuthor && this.el.value === '') {
                    this.el.value = savedAuthor
                  }
                }
              }
            </script>
            <.button type="submit" variant="primary" phx-disable-with="Publishing...">
              Publish
            </.button>
          </div>
        </.form>
      </div>
      <ul class="flex flex-col gap-2 mt-4" id="posts" phx-update="stream">
        <li
          :for={{dom_id, post} <- @streams.posts}
          id={dom_id}
          class="bg-base-300 p-4 rounded-lg relative"
        >
          <div class={["text-xl whitespace-pre-wrap", @admin? && "pr-3"]}>{post.text}</div>
          <div class="text-right">{post.author}</div>
          <button
            :if={@admin?}
            class="absolute top-2 right-2 cursor-pointer hover:bg-slate-500 rounded"
            phx-click={JS.push("delete_post", value: %{id: post.id})}
          >
            <span class="sr-only">Delete post {post.id}</span>
            <.icon name="hero-x-mark" class="size-6" />
          </button>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("change", %{"topic" => topic}, socket) when is_admin(socket) do
    Application.put_env(:my_system, :bulletin_board, topic)
    Phoenix.PubSub.broadcast!(MySystem.PubSub, @pubsub_topic, {:topic_changed, topic})
    socket |> push_navigate(to: ~p"/board/#{topic}/admin") |> noreply()
  end

  def handle_event("validate", %{"post" => params}, socket) do
    changeset = change_post(params) |> Map.put(:action, :validate)
    assign(socket, :form, to_form(changeset, as: :post)) |> noreply()
  end

  def handle_event("submit", %{"post" => params}, socket) do
    changeset = change_post(params) |> Map.put(:action, :insert)

    if changeset.valid? do
      %{author: author, text: text} = Ecto.Changeset.apply_changes(changeset)
      _pid = MySystem.BulletinBoard.publish_post(author, text, socket.assigns.topic)
      assign(socket, :form, to_form(%{}, as: :post)) |> noreply()
    else
      assign(socket, :form, to_form(changeset, as: :post)) |> noreply()
    end
  end

  def handle_event("delete_post", %{"id" => id}, socket) when is_admin(socket) do
    :ok = MySystem.BulletinBoard.delete_post(socket.assigns.topic, id)
    noreply(socket)
  end

  @impl true
  def handle_info({:new_post, post}, socket) do
    stream_insert(socket, :posts, post, at: 0) |> noreply()
  end

  def handle_info({:deleted_post, post}, socket) do
    stream_delete(socket, :posts, post) |> noreply()
  end

  def handle_info({:topic_changed, topic}, socket) do
    if topic != socket.assigns.topic do
      push_navigate(socket, to: ~p"/board/#{topic}") |> noreply()
    else
      socket |> noreply()
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    if reason != :normal do
      put_flash(socket, :error, "Posting of Message failed.") |> noreply()
    else
      noreply(socket)
    end
  end

  defp load_posts(socket) do
    {:ok, posts} = MySystem.BulletinBoard.list_posts(socket.assigns.topic)
    stream(socket, :posts, Enum.reverse(posts), reset: true)
  end

  defp change_post(params) do
    types = %{author: :string, text: :string}

    trim = fn
      binary when is_binary(binary) -> String.trim(binary)
      other -> other
    end

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required(~w(author text)a)
    |> Ecto.Changeset.update_change(:author, trim)
    |> Ecto.Changeset.update_change(:text, trim)
    |> Ecto.Changeset.validate_length(:author, min: 3)
    |> Ecto.Changeset.validate_length(:text, min: 3)
  end

  defp long_topic(@buildingblocks), do: "What are your building blocks for robust systems?"
  defp long_topic(@observability), do: "How do you find a misbehaving part of your software?"
end

defmodule MySystemWeb.BulletinBoard do
  use MySystemWeb, :live_view

  @buildingblocks "buildingblocks"
  @observability "observability"

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket
    |> assign(:form, to_form(%{}, as: :post))
    |> assign(:show_form, true)
    |> ok()
  end

  @impl Phoenix.LiveView
  def handle_params(%{"topic" => topic}, _uri, socket)
      when topic not in [@buildingblocks, @observability] do
    push_navigate(socket, to: ~p"/bulletin_board/#{@buildingblocks}") |> noreply()
  end

  def handle_params(%{"topic" => topic}, _uri, socket) do
    :ok = MySystem.BulletinBoard.subscribe(topic)

    socket
    |> assign(:topic, topic)
    |> load_posts()
    |> noreply()
  end

  defp long_topic(@buildingblocks), do: "What are your building blocks for robust systems?"
  defp long_topic(@observability), do: "How do you find a misbehaving part of your software?"

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>{long_topic(@topic)}</.header>
      <div class="p-4 bg-slate-200 rounded-lg">
        <button phx-click={
          JS.toggle(to: "#form") |> JS.toggle_class("rotate-180", to: "#toggle-form-icon")
        }>
          <.icon id="toggle-form-icon" name="hero-chevron-up" class="size-5" />
        </button>
        <.form for={@form} id="form" class="mt-4" phx-change="validate" phx-submit="submit">
          <div class="block">
            <.input
              placeholder="Your post"
              field={@form[:text]}
              type="textarea"
              phx-debounce
              rows="10"
              cols="80"
            />
          </div>
          <div class="mt-2 block">
            <.input placeholder="Your name" field={@form[:author]} phx-debounce />
            <.button type="submit" variant="primary" phx-disable-with="Publishing...">
              Publish
            </.button>
          </div>
        </.form>
      </div>
      <ul class="flex flex-col gap-2 mt-4">
        <li :for={post <- @posts} class="bg-slate-200 p-4 rounded-lg">
          <pre class="text-xl">{post.text}</pre>
          <div class="text-right">{post.author}</div>
        </li>
      </ul>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
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

  @impl true
  def handle_info({:new_post, _id}, socket) do
    load_posts(socket) |> noreply()
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    if reason != :normal do
      put_flash(socket, :error, "Posting of Message failed.") |> noreply()
    else
      noreply(socket)
    end
  end

  defp load_posts(socket) do
    {:ok, posts} = MySystem.BulletinBoard.list_posts(socket.assigns.topic, 0, 100)
    assign(socket, :posts, posts)
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
end

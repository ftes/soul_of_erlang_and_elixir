defmodule MySystemWeb.Router do
  use MySystemWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MySystemWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  import Plug.BasicAuth

  pipeline :authenticated do
    if Mix.env() != :test do
      plug :basic_auth, username: "hello", password: "secret"
    end
  end

  scope "/", MySystemWeb do
    pipe_through :browser

    live "/", Math
    live "/bulletin_board/:topic", BulletinBoard
  end

  scope "/", MySystemWeb do
    pipe_through [:browser, :authenticated]

    live "/bulletin_board/:topic/admin", BulletinBoard, :admin

    live_dashboard "/dashboard",
      metrics: MySystemWeb.Telemetry,
      additional_pages: [load_control: MySystemWeb.LoadControl]
  end

  # Other scopes may use custom stacks.
  # scope "/api", MySystemWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:my_system, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).

    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

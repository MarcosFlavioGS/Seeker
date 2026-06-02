defmodule SeekerWeb.Router do
  use SeekerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SeekerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SeekerWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/orgs/:org/:env", QueryLive
  end
end

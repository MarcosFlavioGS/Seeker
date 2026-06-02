defmodule SeekerWeb.PageController do
  use SeekerWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/orgs/just_travel/prod")
  end
end

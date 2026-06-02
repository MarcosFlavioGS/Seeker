defmodule SeekerWeb.ConnCase do
  @moduledoc """
  Test case for tests that require an HTTP connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint SeekerWeb.Endpoint

      use SeekerWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import SeekerWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end

defmodule Seeker.JustTravel.ProdRepo do
  use Ecto.Repo,
    otp_app: :seeker,
    adapter: Ecto.Adapters.Postgres
end

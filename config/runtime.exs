import Config
import Dotenvy

# Load .env from the project root, then let actual env vars override it.
source!([".env", System.get_env()])

if System.get_env("PHX_SERVER") do
  config :seeker, SeekerWeb.Endpoint, server: true
end

config :seeker, SeekerWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# ── Just Travel ──────────────────────────────────────────────────────────────

just_travel_ssl_mode =
  case env!("JUST_TRAVEL_DB_SSL_MODE", :string, "verify_none") do
    "verify_peer" -> :verify_peer
    _ -> :verify_none
  end

just_travel_ssl_opts =
  if just_travel_ssl_mode == :verify_peer do
    cacert =
      env!(
        "JUST_TRAVEL_DB_SSL_CACERT",
        :string,
        "/etc/ssl/certs/ca-certificates.crt"
      )

    [verify: :verify_peer, cacertfile: cacert]
  else
    [verify: :verify_none]
  end

config :seeker, Seeker.JustTravel.ProdRepo,
  hostname: env!("JUST_TRAVEL_PROD_DB_HOST", :string, nil),
  port: env!("JUST_TRAVEL_PROD_DB_PORT", :integer, 5432),
  username: env!("JUST_TRAVEL_PROD_DB_USER", :string, nil),
  password: env!("JUST_TRAVEL_PROD_DB_PASS", :string, nil),
  database: env!("JUST_TRAVEL_PROD_DB_NAME", :string, nil),
  ssl: just_travel_ssl_opts,
  pool_size: 2,
  connect_timeout: 10_000,
  log: false

config :seeker, Seeker.JustTravel.HomoRepo,
  hostname: env!("JUST_TRAVEL_HOMO_DB_HOST", :string, nil),
  port: env!("JUST_TRAVEL_HOMO_DB_PORT", :integer, 5432),
  username: env!("JUST_TRAVEL_HOMO_DB_USER", :string, nil),
  password: env!("JUST_TRAVEL_HOMO_DB_PASS", :string, nil),
  database: env!("JUST_TRAVEL_HOMO_DB_NAME", :string, nil),
  ssl: just_travel_ssl_opts,
  pool_size: 2,
  connect_timeout: 10_000,
  log: false

# ── Add new organizations below this line ────────────────────────────────────
# config :seeker, Seeker.Acme.ProdRepo,
#   hostname: env!("ACME_PROD_DB_HOST", :string),
#   port: env!("ACME_PROD_DB_PORT", :integer, 5432),
#   username: env!("ACME_PROD_DB_USER", :string),
#   password: env!("ACME_PROD_DB_PASS", :string),
#   database: env!("ACME_PROD_DB_NAME", :string),
#   ssl: [verify: :verify_none],
#   pool_size: 2,
#   connect_timeout: 10_000,
#   log: false

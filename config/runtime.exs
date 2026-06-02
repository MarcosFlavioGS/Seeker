import Config
import Dotenvy

# Load .env from the project root (system env vars take precedence).
# Also push all loaded values into the system env so that LocalConfig
# can read them via System.get_env/1 at application start time.
System.put_env(source!([".env", System.get_env()]))

if System.get_env("PHX_SERVER") do
  config :seeker, SeekerWeb.Endpoint, server: true
end

config :seeker, SeekerWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

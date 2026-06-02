defmodule SeekerWeb.ConnStatus do
  @moduledoc "Connection status badge helpers, available in all LiveViews."

  def badge_class(:connected), do: "badge-success"
  def badge_class({:error, :vpn_down}), do: "badge-error"
  def badge_class({:error, :bad_credentials}), do: "badge-warning"
  def badge_class(_), do: "badge-ghost"

  def badge_text(:connected), do: "Connected"
  def badge_text({:error, :vpn_down}), do: "VPN down"
  def badge_text({:error, :bad_credentials}), do: "Auth error"
  def badge_text(:unknown), do: "Checking..."
  def badge_text(_), do: "Unknown"
end

defmodule Seeker.OrgRegistry do
  @moduledoc """
  Runtime registry of organizations and their environments.

  Populated once at application start from `Seeker.LocalConfig.load_orgs/0`
  and stored in `:persistent_term` for fast concurrent reads.

  Keys are slug strings (e.g. `"just_travel"`).
  Repo names are atoms (e.g. `:"seeker_repo_just_travel_prod"`).
  """

  @key :seeker_org_registry

  @doc "Called once during Application.start/2 with the loaded org map."
  def setup(orgs) when is_map(orgs) do
    :persistent_term.put(@key, orgs)
  end

  @doc "Returns all organizations as `%{slug => org_info}`."
  def all, do: :persistent_term.get(@key, %{})

  @doc "Returns the environment entry for a given org and env (both strings), or nil."
  def get(org, env) when is_binary(org) and is_binary(env) do
    get_in(all(), [org, :environments, env])
  end

  @doc "Returns org info for a given slug string, or nil."
  def get_org(org) when is_binary(org) do
    Map.get(all(), org)
  end

  @doc "Returns a list of all repo process names across all orgs and environments."
  def all_repos do
    for {_org, %{environments: envs}} <- all(),
        {_env, %{repo: repo}} <- envs,
        do: repo
  end
end

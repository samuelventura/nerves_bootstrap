defmodule Nerves.Bootstrap do
  @moduledoc false
  use Application

  @version Mix.Project.config()[:version]

  @impl Application
  def start(_type, _args) do
    Nerves.Bootstrap.Aliases.init()
    {:ok, self()}
  end

  @doc """
  Returns the version of nerves_bootstrap
  """
  @spec version() :: String.t()
  def version(), do: @version

  @doc """
  Add the required Nerves bootstrap aliases to the existing ones
  """
  defdelegate add_aliases(aliases), to: Nerves.Bootstrap.Aliases

  @doc """
  Check the nerves_bootstrap updates from hex
  """
  @spec check_for_update() :: :ok
  def check_for_update() do
    Hex.start()
    {:ok, {200, resp, _}} = Hex.API.Package.get("hexpm", "nerves_bootstrap")

    current_version =
      Nerves.Bootstrap.version()
      |> Version.parse!()

    release_versions =
      resp
      |> Map.get("releases")
      |> Enum.map(&Map.get(&1, "version"))
      |> Enum.map(&Version.parse!/1)

    case check_for_update(release_versions, current_version) do
      nil ->
        :ok

      latest_version ->
        render_update_message(current_version, latest_version)
    end
  rescue
    _e -> :ok
  end

  @spec check_for_update([Version.t()], Version.t()) :: Version.t() | nil
  def check_for_update(releases, current_version) do
    releases
    |> filter_pre_release(current_version)
    |> Enum.filter(&(Version.compare(&1, current_version) == :gt))
    |> Enum.sort(&(Version.compare(&1, &2) == :gt))
    |> List.first()
  end

  @spec render_update_message(any, %{:pre => any, optional(any) => any}) :: :ok
  def render_update_message(current_version, %{pre: pre} = latest_version) do
    message =
      "A new version of Nerves bootstrap is available(#{current_version} < #{latest_version}), " <>
        if pre == [] do
          """
          You can update by running

            mix local.nerves
          """
        else
          """
          You can update by running

            mix archive.install hex nerves_bootstrap #{latest_version}
          """
        end

    Mix.shell().info([:yellow, message, :reset])
  end

  @spec mix_target() :: atom()
  def mix_target() do
    if function_exported?(Mix, :target, 0) do
      apply(Mix, :target, [])
    else
      (System.get_env("MIX_TARGET") || "host")
      |> String.to_atom()
    end
  end

  defp filter_pre_release(releases, %{pre: []}) do
    releases
    |> Enum.filter(&(Map.get(&1, :pre) == []))
  end

  defp filter_pre_release(releases, %{major: major, minor: minor, patch: patch}) do
    releases
    |> Enum.filter(fn
      %{pre: []} ->
        true

      %{major: ^major, minor: ^minor, patch: ^patch} ->
        true

      _ ->
        false
    end)
  end
end

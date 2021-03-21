defmodule FarmbotCore.EctoMigrator do
  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :migrate, []},
      type: :worker,
      restart: :transient,
      shutdown: 500
    }
  end

  @doc "Replacement for Mix.Tasks.Ecto.Migrate"
  def migrate do
    repos = Application.get_env(:farmbot_core, :ecto_repos)
    for repo <- repos, do: migrate(repo)
    :ignore
  end

  def migrate(FarmbotCore.Asset.Repo) do
    migrate(FarmbotCore.Asset.Repo, Path.join([:code.priv_dir(:farmbot_core), "asset", "migrations"]))
  end

  def migrate(FarmbotCore.Logger.Repo) do
    migrate(FarmbotCore.Logger.Repo, Path.join([:code.priv_dir(:farmbot_core), "logger", "migrations"]))
  end

  def migrate(FarmbotCore.Config.Repo) do
    migrate(FarmbotCore.Config.Repo, Path.join([:code.priv_dir(:farmbot_core), "config", "migrations"]))
  end

  def migrate(repo, migrations_path) do
    opts = [all: true]
    {:ok, pid, apps} = Mix.Ecto.ensure_started(repo, opts)

    migrator = &Ecto.Migrator.run/4
    # HERE:
    migrated = migrator.(repo, migrations_path, :up, opts)
    pid && repo.stop(pid)
    restart_apps_if_migrated(apps, migrated)
    Process.sleep(500)
  end

  # Pulled this out of Ecto because Ecto's version
  # messes with Logger config
  def restart_apps_if_migrated(_, []), do: :ok

  def restart_apps_if_migrated(apps, [_|_]) do
    for app <- Enum.reverse(apps) do
      Application.stop(app)
    end
    for app <- apps do
      Application.ensure_all_started(app)
    end
    :ok
  end

  @doc "Replacement for Mix.Tasks.Ecto.Drop"
  def drop do
    repos = Application.get_env(:farmbot_core, :ecto_repos)

    for repo <- repos do
      case drop(repo) do
        :ok -> :ok
        {:error, :already_down} -> :ok
        {:error, reason} -> raise reason
      end
    end
  end

  def drop(repo) do
    repo.__adapter__.storage_down(repo.config)
  end
end

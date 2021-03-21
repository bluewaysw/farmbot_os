defmodule FarmbotOS.SysCalls.ChangeOwnership do
  @moduledoc false

  require Logger
  require FarmbotCore.Logger
  import FarmbotCore.Config, only: [get_config_value: 3, update_config_value: 4]
  alias FarmbotCore.{Asset, EctoMigrator}
  alias FarmbotExt.Bootstrap.Authorization

  defmodule Support do
    def replace_credentials(email, secret, server) do
      FarmbotCore.Logger.debug(3, "Replacing credentials")
      update_config_value(:string, "authorization", "password", nil)
      update_config_value(:string, "authorization", "token", nil)
      update_config_value(:string, "authorization", "email", email)
      update_config_value(:string, "authorization", "server", server)
      update_config_value(:string, "authorization", "secret", secret)
      :ok
    end

    def soft_restart do
      child = {Task, &FarmbotOS.System.soft_restart/0}
      Supervisor.start_child(:elixir_sup, child)
    end

    def clean_assets do
      EctoMigrator.drop(Asset.Repo)
      :ok
    end
  end

  alias FarmbotOS.SysCalls.ChangeOwnership.Support

  def change_ownership(email, secret, server) do
    server = server || get_config_value(:string, "authorization", "server")

    case Authorization.authorize_with_secret(email, secret, server) do
      {:ok, _token} ->
        msg = "Farmbot is changing ownership to #{email} - #{server}"
        FarmbotCore.Logger.warn(1, msg)

        :ok = Support.replace_credentials(email, secret, server)
        :ok = Support.clean_assets()
        Support.soft_restart()
        :ok

      {:error, _} ->
        FarmbotCore.Logger.error(1, "Invalid credentials for change ownership")
        {:error, "Invalid credentials for change ownership"}
    end
  end
end

defmodule FarmbotExt.API.PreloaderTest do
  use ExUnit.Case
  use Mimic

  alias FarmbotCore.Asset.Sync

  alias FarmbotExt.{API, API.Preloader}
  setup :verify_on_exit!

  test "get sync error" do
    expect(API, :get_changeset, fn Sync ->
      {:error, "some descriptive API error"}
    end)

    assert {:error, "some descriptive API error"} = Preloader.preload_all()
  end
end

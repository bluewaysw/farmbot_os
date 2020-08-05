defmodule AutoSyncChannelTest do
  require Helpers
  use ExUnit.Case, async: false
  use Mimic
  alias FarmbotExt.AMQP.AutoSyncChannel

  alias FarmbotExt.{
    AMQP.ConnectionWorker,
    API.Preloader,
    JWT
  }

  setup :verify_on_exit!
  setup :set_mimic_global

  @fake_jwt "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhZ" <>
              "G1pbkBhZG1pbi5jb20iLCJpYXQiOjE1MDIxMjcxMTcsImp0a" <>
              "SI6IjlhZjY2NzJmLTY5NmEtNDhlMy04ODVkLWJiZjEyZDlhY" <>
              "ThjMiIsImlzcyI6Ii8vbG9jYWxob3N0OjMwMDAiLCJleHAiO" <>
              "jE1MDU1ODMxMTcsIm1xdHQiOiJsb2NhbGhvc3QiLCJvc191c" <>
              "GRhdGVfc2VydmVyIjoiaHR0cHM6Ly9hcGkuZ2l0aHViLmNvb" <>
              "S9yZXBvcy9mYXJtYm90L2Zhcm1ib3Rfb3MvcmVsZWFzZXMvb" <>
              "GF0ZXN0IiwiZndfdXBkYXRlX3NlcnZlciI6Imh0dHBzOi8vY" <>
              "XBpLmdpdGh1Yi5jb20vcmVwb3MvRmFybUJvdC9mYXJtYm90L" <>
              "WFyZHVpbm8tZmlybXdhcmUvcmVsZWFzZXMvbGF0ZXN0IiwiY" <>
              "m90IjoiZGV2aWNlXzE1In0.XidSeTKp01ngtkHzKD_zklMVr" <>
              "9ZUHX-U_VDlwCSmNA8ahOHxkwCtx8a3o_McBWvOYZN8RRzQV" <>
              "LlHJugHq1Vvw2KiUktK_1ABQ4-RuwxOyOBqqc11-6H_GbkM8" <>
              "dyzqRaWDnpTqHzkHGxanoWVTTgGx2i_MZLr8FPZ8prnRdwC1" <>
              "x9zZ6xY7BtMPtHW0ddvMtXU8ZVF4CWJwKSaM0Q2pTxI9GRqr" <>
              "p5Y8UjaKufif7bBPOUbkEHLNOiaux4MQr-OWAC8TrYMyFHzt" <>
              "eXTEVkqw7rved84ogw6EKBSFCVqwRA-NKWLpPMV_q7fRwiEG" <>
              "Wj7R-KZqRweALXuvCLF765E6-ENxA"

  def generate_pid do
    apply_default_mocks()
    jwt = JWT.decode!(@fake_jwt)
    {:ok, pid} = AutoSyncChannel.start_link([jwt: jwt], [])
    pid
  end

  def apply_default_mocks do
    ok1 = fn _ -> :whatever end
    stub(FarmbotExt.API.EagerLoader.Supervisor, :drop_all_cache, fn -> :ok end)
    stub(ConnectionWorker, :close_channel, ok1)

    stub(ConnectionWorker, :maybe_connect_autosync, fn _ ->
      %{conn: %{fake_conn: true}, chan: %{fake_chan: true}}
    end)
  end

  def ensure_response_to(msg) do
    # Not much to check here other than matching clauses.
    # AMQP lib handles most all of this.
    expect(Preloader, :preload_all, 1, fn -> :ok end)
    pid = generate_pid()
    send(pid, msg)
    Helpers.wait_for(pid)
  end

  test "basic_cancel", do: ensure_response_to({:basic_cancel, :anything})
  test "basic_cancel_ok", do: ensure_response_to({:basic_cancel_ok, :anything})
  test "basic_consume_ok", do: ensure_response_to({:basic_consume_ok, :anything})

  test "init / terminate - auto_sync enabled" do
    expect(Preloader, :preload_all, 1, fn -> :ok end)
    expect(FarmbotCore.BotState, :set_sync_status, 1, fn "synced" -> :ok end)

    expect(FarmbotCore.Leds, :green, 2, fn
      :solid ->
        :ok

      :really_fast_blink ->
        :ok
    end)

    pid = generate_pid()
    assert %{chan: nil, conn: nil, preloaded: true} == AutoSyncChannel.network_status(pid)
    GenServer.stop(pid, :normal)
  end

  test "init / terminate - preload error" do
    expect(Preloader, :preload_all, 1, fn -> {:error, "part of a test"} end)
    expect(FarmbotCore.BotState, :set_sync_status, 1, fn "sync_error" -> :ok end)

    pid = generate_pid()
    assert %{chan: nil, conn: nil, preloaded: false} == AutoSyncChannel.network_status(pid)
    GenServer.stop(pid, :normal)
  end

  test "delivery of auto sync messages" do
    expect(Preloader, :preload_all, 1, fn -> :ok end)

    expect(ConnectionWorker, :rpc_reply, 1, fn chan, device, label ->
      assert chan == %{fake_chan: true}
      assert device == "device_15"
      assert label == "thisismylabelinatestsuite"
      :ok
    end)

    key = "bot.device_15.sync.Device.46"

    {:ok, payload} =
      FarmbotCore.JSON.encode(%{
        "id" => 46,
        "args" => %{
          "label" => "thisismylabelinatestsuite"
        },
        "body" => %{name: "This is my bot"}
      })

    pid = generate_pid()
    # We need the process to be preloaded for these tests to work:
    %{preloaded: true} = AutoSyncChannel.network_status(pid)
    send(pid, {:basic_deliver, payload, %{routing_key: key}})

    expect(FarmbotExt.AMQP.AutoSyncAssetHandler, :handle_asset, fn kind, id, body ->
      assert kind == "Device"
      assert id == 46
      assert body == %{"name" => "This is my bot"}
      :ok
    end)

    Helpers.wait_for(pid)
    Process.sleep(1000)
  end
end

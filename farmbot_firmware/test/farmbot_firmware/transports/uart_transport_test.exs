defmodule FarmbotFirmware.UARTTransportTest do
  use ExUnit.Case
  use Mimic
  doctest FarmbotFirmware.UARTTransport
  alias FarmbotFirmware.{UartDefaultAdapter, UARTTransport}
  setup :verify_on_exit!
  import ExUnit.CaptureLog
  import ExUnit.CaptureLog

  test "UARTTransport.init/1" do
    expect(UartDefaultAdapter, :start_link, fn ->
      {:ok, :FAKE_UART}
    end)

    init_args = [
      device: :FAKE_DEVICE,
      handle_gcode: :FAKE_GCODE_HANDLER,
      reset: StubReset
    ]

    {:ok, state, 0} = UARTTransport.init(init_args)
    assert state.device == Keyword.fetch!(init_args, :device)
    assert state.handle_gcode == Keyword.fetch!(init_args, :handle_gcode)
    assert state.reset == Keyword.fetch!(init_args, :reset)
  end

  test "UARTTransport.terminate/2" do
    expect(UartDefaultAdapter, :stop, fn uart ->
      assert uart == :whatever
    end)

    state = %{uart: :whatever}
    UARTTransport.terminate(nil, state)
  end

  test "UARTTransport resets UART on timeout" do
    state = %{uart: :FAKE_UART, device: :FAKE_DEVICE, open: false}

    fake_opts = [fake_opts: true]

    expect(UartDefaultAdapter, :generate_opts, fn ->
      fake_opts
    end)

    expect(UartDefaultAdapter, :open, fn uart, dev, opts ->
      assert uart == state.uart
      assert dev == state.device
      assert fake_opts == opts
      :ok
    end)

    {:noreply, state2} = UARTTransport.handle_info(:timeout, state)
    # Expect the `open` state to toggle back to "true" from "false":
    refute state.open == state2.open
  end

  test "UARTTransport handles unexpected UART errors" do
    state = %{uart: :FAKE_UART, device: :FAKE_DEVICE, open: false}

    fake_opts = [fake_opts: true]

    expect(UartDefaultAdapter, :generate_opts, fn ->
      fake_opts
    end)

    error = "Simulated UART failure. This is OK"

    expect(UartDefaultAdapter, :open, fn _, _, _ ->
      {:error, error}
    end)

    logs =
      capture_log(fn ->
        {:noreply, state2, retry_timeout} =
          UARTTransport.handle_info(:timeout, state)

        assert retry_timeout == 5000
        assert state.open == state2.open
      end)

    assert logs =~ error
  end

  test "UARTTransport handles `Circuits-UART` speecific errors" do
    state = %{uart: :FAKE_UART, device: :FAKE_DEVICE, open: false}
    provided_reason = "Simulated failure (circuits UART)"
    info = {:circuits_uart, nil, {:error, provided_reason}}

    {:stop, {:uart_error, reason}, state2} =
      UARTTransport.handle_info(info, state)

    assert reason == provided_reason
    assert state == state2
  end

  test "UARTTransport handling inbound `Circuits-UART` data" do
    state = %{
      uart: :FAKE_UART,
      device: :FAKE_DEVICE,
      open: false,
      handle_gcode: fn gcode ->
        assert gcode == {nil, {:command_movement, []}}
      end
    }

    provided_data = "G00"
    info = {:circuits_uart, nil, provided_data}
    {:noreply, state2} = UARTTransport.handle_info(info, state)
    assert state2 == state
  end

  test "writing to UART" do
    code = {nil, {:command_movement, []}}
    state = %{uart: :FAKE_UART, device: :FAKE_DEVICE, open: false}

    expect(UartDefaultAdapter, :write, fn _pid, code ->
      assert "G00 " == code
      :whatever
    end)

    {:reply, :whatever, state2} = UARTTransport.handle_call(code, nil, state)
    assert state2 == state
  end

  test "UARTTransport.reset/2" do
    empty_state = %{reset: nil}
    ok_state = %{reset: %{reset: :fake_reset}}
    assert :ok == UARTTransport.reset(empty_state)
    assert :fake_reset == UARTTransport.reset(ok_state)
  end

  test "UARTTransport.open/2" do
    me = self()

    expect(UartDefaultAdapter, :open, fn pid, path, opts ->
      assert pid == me
      assert path == "/dev/null"
      assert opts == [a: :b]
    end)

    UARTTransport.open(me, "/dev/null", a: :b)
  end

  test "handle_info for unknown messages" do
    bad_payl = {:partial, <<130, 135, 7, 53, 65, 34>>}
    bad_message = {:circuits_uart, "ttyAMA0", bad_payl}
    fake_state = %{}

    log =
      capture_log(fn ->
        result = UARTTransport.handle_info(bad_message, fake_state)
        assert result == {:noreply, fake_state}
      end)

    expected =
      "UNHANDLED UART MESSAGE: " <>
        "{:circuits_uart, \"ttyAMA0\", {:partial, <<130, 135, 7, 53, 65, 34>>}}"

    assert String.contains?(log, expected)
  end
end

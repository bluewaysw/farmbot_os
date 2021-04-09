defmodule FarmbotCore.Firmware.GCodeDecoderTest do
  use ExUnit.Case
  alias FarmbotCore.Firmware.GCodeDecoder

  @fake_txt [
    "R00 Q0",
    "R81 XA1 XB1 YA1 YB1 ZA1 ZB1 Q0",
    "R82 X0.00 Y0.00 Z0.00 Q0",
    "R84 X0.00 Y0.00 Z0.00 Q0",
    "R85 X0 Y0 Z0 Q0",
    "R88 Q0",
    "R99 ARDUINO STARTUP COMPLETE",
    "R00 Q0",
    "R81 XA1 XB1 YA1 YB1 ZA1 ZB1 Q0",
    "R82 X0.00 Y0.00 Z0.00 Q0",
    "R84 X0.00 Y0.00 Z0.00 Q0",
    "R85 X0 Y0 Z0 Q0",
    "R88 Q0",
    "R99 ARDUINO STARTUP COMPLETE"
  ]

  test "empty input" do
    assert [] == GCodeDecoder.run([])
  end

  test "normal input" do
    expected = [
      idle: %{queue: 0.0},
      end_stops_report: %{queue: 0.0, z_endstop_a: 1.0, z_endstop_b: 1.0},
      current_position: %{queue: 0.0, x: 0.0, y: 0.0, z: 0.0},
      encoder_position_scaled: %{queue: 0.0, x: 0.0, y: 0.0, z: 0.0},
      encoder_position_raw: %{queue: 0.0, x: 0.0, y: 0.0, z: 0.0},
      not_configured: %{queue: 0.0},
      debug_message: "ARDUINO STARTUP COMPLETE",
      idle: %{queue: 0.0},
      end_stops_report: %{queue: 0.0, z_endstop_a: 1.0, z_endstop_b: 1.0},
      current_position: %{queue: 0.0, x: 0.0, y: 0.0, z: 0.0},
      encoder_position_scaled: %{queue: 0.0, x: 0.0, y: 0.0, z: 0.0},
      encoder_position_raw: %{queue: 0.0, x: 0.0, y: 0.0, z: 0.0},
      not_configured: %{queue: 0.0},
      debug_message: "ARDUINO STARTUP COMPLETE"
    ]

    assert expected == GCodeDecoder.run(@fake_txt)
  end

  test "unexpected input" do
    boom = fn -> GCodeDecoder.run(["F21"]) end
    msg = "Expect inbound GCode to begin with `R`. Got: \"F21\""
    assert_raise RuntimeError, msg, boom
  end
end

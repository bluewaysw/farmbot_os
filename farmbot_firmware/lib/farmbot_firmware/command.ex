defmodule FarmbotFirmware.Command do
  @moduledoc false
  # sister module to FarmbotFirmware.Request
  # see docs for FarmbotFirmware.command/1

  alias FarmbotFirmware
  alias FarmbotFirmware.GCODE
  require Logger

  @spec command(GenServer.server(), GCODE.t() | {GCODE.kind(), GCODE.args()}) ::
          :ok
          | {:error,
             :invalid_command
             | :firmware_error
             | :emergency_lock
             | FarmbotFirmware.status()}
  def command(firmware_server \\ FarmbotFirmware, code)

  def command(firmware_server, {_tag, {_, _}} = code) do
    case GenServer.call(firmware_server, code, :infinity) do
      {:ok, _} -> wait_for_command_result(code)
      {:error, status} -> {:error, status}
    end
  end

  def command(firmware_server, {_a, _b} = code) do
    command(firmware_server, {to_string(:rand.uniform(100)), code})
  end

  def wait_for_command_result(original_cmd) do
    # Takes a GCode command.
    # Sits and loops through messages until it finds the one
    # it asked for.
    # It will come back in the form of:
    # {tag, {command_name, command_result}}

    receive do
      {_tag, {:report_begin, []}} ->
        debug_log("#{GCODE.encode(original_cmd)} begin")
        wait_for_command_result(original_cmd)

      {_tag, {:report_busy, []}} ->
        debug_log("#{GCODE.encode(original_cmd)} busy")
        wait_for_command_result(original_cmd)

      {_tag, {:report_success, []}} ->
        debug_log("#{GCODE.encode(original_cmd)} success")
        :ok

      {_tag, {:report_retry, []}} ->
        debug_log("#{GCODE.encode(original_cmd)} retry")
        wait_for_command_result(original_cmd)

      {_tag, {:report_position_change, _}} ->
        debug_log("#{GCODE.encode(original_cmd)} position change")
        # HOW IT WAS BEFORE:
        # wait_for_command_result(code, retries, error)
        wait_for_command_result(original_cmd)

      {_tag, {:report_error, [error_code]}} ->
        debug_log("#{GCODE.encode(original_cmd)} #{inspect(error_code)}")

        case error_code do
          :no_error -> {:ok, "ok"}
          :emergency_lock -> {:error, "emergency lock"}
          :timeout -> {:error, "timeout"}
          :calibration_error -> {:error, "length determination error"}
          :invalid_command -> {:error, "invalid command"}
          :no_config -> {:error, "no configuration"}
          :stall_detected_x -> {:error, "X axis stall detected"}
          :stall_detected_y -> {:error, "Y axis stall detected"}
          :stall_detected_z -> {:error, "Z axis stall detected"}
          error -> {:error, "unknown firmware error #{inspect(error)}"}
        end

      {_tag, {:report_invalid, []}} ->
        debug_log("#{GCODE.encode(original_cmd)} invalid command")
        {:error, :invalid_command}

      {_tag, {:report_emergency_lock, []}} ->
        debug_log("#{GCODE.encode(original_cmd)} e stop")
        {:error, :emergency_lock}

      {_tag, {:report_axis_timeout, [axis]}} ->
        {:error, "axis timeout: #{axis}"}

      {:error, reason} ->
        debug_log("#{GCODE.encode(original_cmd)} unknown error")
        {:error, reason}

      {_tag, report} ->
        debug_log(
          "#{GCODE.encode(original_cmd)} ignored report: #{inspect(report)}"
        )

        wait_for_command_result(original_cmd)
    after
      30_000 ->
        raise(
          "Firmware command: #{GCODE.encode(original_cmd)} failed to respond within 30 seconds"
        )
    end
  end

  # If you ever need this for dev builds, you can add custom logger logic here.
  def debug_log(_msg), do: nil
end

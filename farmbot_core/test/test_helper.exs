Application.ensure_all_started(:mimic)
tz = System.get_env("TZ") || Timex.local().time_zone

FarmbotCore.Asset.Device.changeset(FarmbotCore.Asset.device(), %{timezone: tz})
|> FarmbotCore.Asset.Repo.insert_or_update!()

[
  Circuits.UART,
  FarmbotCeleryScript,
  FarmbotCeleryScript.SysCalls.Stubs,
  FarmbotCore.Asset,
  FarmbotCore.Firmware.ConfigUploader,
  FarmbotCore.Firmware.UARTCore,
  FarmbotCore.Firmware.UARTCoreSupport,
  FarmbotCore.LogExecutor,
  Timex,
  MuonTrap,
  FarmbotCore.Firmware.Resetter,
  FarmbotCore.Firmware.FlashUtils,
  FarmbotCore.BotState,
  FarmbotCore.Firmware.Avrdude
]
|> Enum.map(&Mimic.copy/1)

ExUnit.configure(max_cases: 1)
ExUnit.start()

defmodule FarmbotCeleryScript.MixProject do
  use Mix.Project

  @version Path.join([__DIR__, "..", "VERSION"])
           |> File.read!()
           |> String.trim()
  @elixir_version Path.join([__DIR__, "..", "ELIXIR_VERSION"])
                  |> File.read!()
                  |> String.trim()

  def project do
    [
      app: :farmbot_celery_script,
      version: @version,
      elixir: @elixir_version,
      elixirc_options: [warnings_as_errors: true, ignore_module_conflict: true],
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        test: :test,
        coveralls: :test,
        "coveralls.circle": :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      source_url: "https://github.com/Farmbot/farmbot_os",
      homepage_url: "http://farmbot.io",
      docs: [
        logo: "../farmbot_os/priv/static/farmbot_logo.png",
        extras: Path.wildcard("../docs/**/*.md")
      ]
    ]
  end

  def elixirc_paths(:test),
    do: [
      "lib",
      Path.expand("./test/support"),
      Path.expand("../test/support/celery_script")
    ]

  def elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:farmbot_telemetry, path: "../farmbot_telemetry", env: Mix.env()},
      {:timex, "~> 3.6.2"},
      {:mimic, "~> 1.4.0", only: :test},
      {:jason, "~> 1.2.2"},
      {:excoveralls, "~> 0.13.4", only: [:test], targets: [:host]},
      {:ex_doc, "~> 0.23.0", only: [:dev], targets: [:host], runtime: false}
    ]
  end
end

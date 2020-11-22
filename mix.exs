defmodule Flow.MixProject do
  use Mix.Project

  def project do
    [
      app: :flow,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
    ]
  end

  def application, do: []

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    ]
  end
end

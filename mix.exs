defmodule Withp.MixProject do
  use Mix.Project

  def project do
    [
      app: :withp,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
    ]
  end

  def description do
    """
    Withp, to rhyme with lisp, is a library to smoothly integrate error-
    returning functions into pipelines via monadic types. It enables authors to
    clarify assumptions and handle errors in ways `with` cannot.
    """
  end

  # NOTE: not yet published.
  def package do
    [
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["Tom Simmons"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/tomboyo/withp",
               "Docs"   => "http://hexdocs.pm/withp"}
    ]
  end

  def application, do: []

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
    ]
  end
end

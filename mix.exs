defmodule SqsPipeline.MixProject do
  use Mix.Project

  def project do
    [
      app: :sqs_pipeline,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SqsPipeline.Application, []}
    ]
  end

  defp deps do
    [
      {:gen_stage, "~> 1.2"},
      {:ex_aws, "~> 2.5"},
      {:ex_aws_s3, "~> 2.4"},
      {:ex_aws_sqs, "~> 3.4"},
      {:hackney, "~> 1.18"},
      {:sweet_xml, "~> 0.7"},
      {:jason, "~> 1.4"},
      {:configparser_ex, "~> 4.0"}
    ]
  end
end

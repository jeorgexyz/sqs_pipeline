defmodule GTube do
  use Application

  def start (_Type, _args) do
    import Supervisor.Spec

    children = [
      worker(SQS.Server, []),
      worker(SQS.Producer, []),
      supervisor(SQS.ConsumerSupervisor, ["Pipeline1"], id: 1),
      supervisor(SQS.ConsumerSupervisor, ["Pipeline2"], id: 2),
      supervisor(SQS.ConsumerSupervisor, ["Pipeline3"], id: 3),
    ]

    opts = [ strategy: one_for_one, name: ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end

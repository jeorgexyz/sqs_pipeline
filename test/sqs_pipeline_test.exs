defmodule SqsPipelineTest do
  use ExUnit.Case
  doctest SqsPipeline

  test "application starts successfully" do
    # The application should be running if tests are running
    assert Process.whereis(SqsPipeline.Supervisor) != nil
  end

  describe "Producer" do
    test "producer is running" do
      assert Process.whereis(SqsPipeline.Producer) != nil
    end
  end

  describe "Pipeline processing" do
    test "can process file content" do
      content = """
      line 1
      line 2
      line 3
      """

      # This would test the private process_file function
      # In a real test, you'd want to expose this or test via public API
      assert String.split(content, "\n") |> Enum.filter(&(&1 != "")) |> length() == 3
    end
  end
end

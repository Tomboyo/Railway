defmodule RailwayTest do
  use ExUnit.Case

  import Railway

  test "on_error_return terminates the railway on error" do
    assert "Expected" == of_one(:v0)
      |> map_ok(fn :v0 -> {:ok, :v1} end)
      # this handler is ignored because the element is ok
      |> on_error_return(&is_not_called/1)
      |> map_ok(fn :v1 -> {:error, :e1} end)
      |> on_error_return(fn :e1 -> "Expected" end)
      # the rest of the Railway is preempted
      |> map_ok(&is_not_called/1)
      |> on_error_return(&is_not_called/1)
      |> eval()
  end

  test "map and return (ok)" do
    assert :v2 == of_one(:v0)
      |> map_ok(fn :v0 -> {:ok, :v1} end)
      |> on_ok_return(fn :v1 -> :v2 end)
      |> eval()
  end

  test "map and return (error)" do
    assert :e2 == error(:e0)
      |> map_error(fn :e0 -> {:ok, :e1} end)
      |> on_error_return(fn :e1 -> :e2 end)
      |> eval()
  end

  test "a terminal combinator is required" do
    assert_raise ArgumentError, fn ->
      of_one(:v1) |> eval()
    end
  end

  defp is_not_called(_) do
    flunk("This function should not be called")
  end
end

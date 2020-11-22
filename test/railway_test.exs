defmodule RailwayTest do
  use ExUnit.Case

  import Railway

  test "use-case" do
    pipeline = fn f1, f2 ->
      fn flow ->
        flow
        |> map_ok(f1)
        |> on_error_return(fn _ -> :e1 end)
        |> map_ok(f2)
        |> on_error_return(fn _ -> :e2 end)
        |> on_ok_return(fn x -> x end)
      end
    end

    assert :v2 == of_one(:v0)
      |> compose(pipeline.(
             fn :v0 -> {:ok, :v1} end,
             fn :v1 -> {:ok, :v2} end))
      |> eval()

    assert :e1 == of_one(:v0)
      |> compose(pipeline.(
             fn :v0 -> {:error, :e1} end,
             &is_not_called/1))
      |> eval()
    
    assert :e2 == of_one(:v0)
      |> compose(pipeline.(
             fn :v0 -> {:ok, :v1} end,
             fn :v1 -> {:error, :e2} end))
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

  defp is_not_called(_) do
    flunk("This function should not be called")
  end
end

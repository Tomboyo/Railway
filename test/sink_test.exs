defmodule Withp.SinkTest do
    use ExUnit.Case
    import Withp.Sink

    test "A matching guard preempts further processing" do
        actual = from(:a)
            |> guard(&f_true/1, fn :a -> :b end)
            |> guard(&is_not_called/1, &is_not_called/1)
            |> transform(&is_not_called/1)
            |> finish()
        
        assert :b == actual
    end

    test "An unmatched guard allows further processing" do
        actual = from(:a)
            |> guard(&f_false/1, &is_not_called/1)
            |> transform(fn :a -> :b end)
            |> guard(&f_false/1, &is_not_called/1)
            |> transform(fn :b -> :c end)
            |> finish()
        
        assert :c == actual
    end

    test "Transforms unconditionally advance computation" do
        actual = from(:a)
            |> transform(fn :a -> :b end)
            |> transform(fn :b -> :c end)
            |> finish()
        
        assert :c == actual
    end

    test "Exhaustive guard clauses may be in terminal position" do
        actual = from(:a)
            |> guard(&f_false/1, &is_not_called/1)
            |> guard(&f_true/1, fn :a -> :b end)
            |> finish()
        
        assert :b == actual
    end

    test "Terminal guard clauses must be exhaustive" do
        actual = from(:a)
            |> guard(&f_false/1, &is_not_called/1)
            |> guard(&f_false/1, &is_not_called/1)
        
        assert_raise RuntimeError, fn ->
            finish(actual)
        end
    end

    # Fake predicate which tests positive for any argument.
    defp f_true(_), do: true

    # Fake predicate which tests negative for any argument.
    defp f_false(_), do: false

    # Fake consequent that we do not expect to be invoked by the subject. We
    # flunk the test if it is invoked.
    defp is_not_called(_) do
        flunk("This function should not be called")
    end
end

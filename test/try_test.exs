defmodule WithpTest do
  use ExUnit.Case
  doctest Withp.Try
  import Withp.Try

  describe "map_ok!/2" do
    test "raises ArgumentError when the first parameter is not a Try" do
      assert_raise ArgumentError, fn ->
        map_ok!(:not_a_try, fn _ -> nil end)
      end
    end

    test "raises ArgumentError when the ok_function evaluates to :error" do
      assert_raise ArgumentError, fn ->
        ok(:in) |> map_ok!(fn :in -> :error end)
      end
    end

    test "raises ArgumentError when the ok_function evaluates to {:error, _}" do
      assert_raise ArgumentError, fn ->
        ok(:in) |> map_ok!(fn :in -> {:error, nil} end)
      end
    end

    test "transforms the value of an ok" do
      assert ok(:out) == map_ok!(ok(:in), fn :in -> :out end)
    end

    test "returns any given error" do
      assert error() == map_ok!(error(), fn _ -> :out end)
    end
  end

  describe "map_ok/3" do
    test "raises ArgumentError when the first parameter is not a Try" do
      assert_raise ArgumentError, fn ->
        map_ok(:not_a_try, :tag, fn _ -> nil end)
      end
    end

    test "returns any given error" do
      assert error() == map_ok(error(), :tag, fn _ -> nil end)
    end

    test "transforms the value of an ok" do
      assert ok(:out) == map_ok(ok(:in), :tag, fn :in -> :out end)
    end

    test "transforms an ok into an error with no payload" do
      assert error(:tag, :in, nil) ==
               map_ok(ok(:in), :tag, fn :in -> :error end)
    end

    test "transforms an ok into an error with a payload" do
      assert error(:tag, :in, :payload) ==
               map_ok(ok(:in), :tag, fn :in -> {:error, :payload} end)
    end
  end

  describe "flat_map/2" do
    test "raises ArgumentError when the first parameter is not a Try" do
      assert_raise ArgumentError, fn ->
        flat_map(:not_a_try, fn _ -> ok(nil) end)
      end
    end

    test "returns any given error" do
      assert error() == flat_map(error(), fn _ -> ok(nil) end)
    end

    test "transforms an ok to an ok" do
      assert ok(:out) == flat_map(ok(:in), fn :in -> ok(:out) end)
    end

    test "transforms an ok to an error" do
      assert error() == flat_map(ok(:in), fn :in -> error() end)
    end

    test "raises ArgumentError if ok_function does not evaluate to a Try" do
      assert_raise ArgumentError, fn ->
        flat_map(ok(:in), fn :in -> :not_a_try end)
      end
    end
  end

  describe "reduce/3" do
    test "raises ArgumentError when the first parameter is not a Try" do
      assert_raise ArgumentError, fn ->
        reduce(:not_a_try, fn _ -> nil end, fn _ -> nil end)
      end
    end

    test "transforms an ok into any term" do
      assert :out =
               ok(:in)
               |> reduce(
                 fn :in -> :out end,
                 fn _ -> nil end
               )
    end

    test "transforms an error into any term" do
      assert :out =
               error(:tag, :in, :payload)
               |> reduce(
                 fn _ -> nil end,
                 fn {:tag, :in, :payload} -> :out end
               )
    end
  end
end

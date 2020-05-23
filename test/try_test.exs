defmodule WithpTest do
  use ExUnit.Case
  doctest Withp.Try
  import Withp.Try

  defp id(x), do: x
  defp unused(_), do: assert false, "this function must not be called"

  describe "of/2" do
    test "creates a Try from a function value" do
      assert :value ==
        of(:tag, fn -> :value end)
        |> reduce(&id/1, &unused/1)
    end

    test "destructures ok tuples into a new Try" do
      assert :value ==
        of(:tag, fn -> {:ok, :value} end)
        |> reduce(&id/1, &unused/1)
    end

    test "creates a Try from a function error" do
      assert {:tag, :no_value, :no_context} ==
        of(:tag, fn -> :error end)
        |> reduce(&unused/1, &id/1)
    end

    test "destructures error context into a new Try" do
      assert {:tag, :no_value, :context} ==
        of(:tag, fn -> {:error, :context} end)
        |> reduce(&unused/1, &id/1)
    end
  end

  describe "of!/1" do
    test "raises ArgumentError when the function evaluates to an error" do
      assert_raise ArgumentError, fn ->
        of!(fn -> :error end)
      end
    end

    test "raises ArgumentError when the function evaluates to an {:error, _}" do
      assert_raise ArgumentError, fn ->
        of!(fn -> {:error, :context} end)
      end
    end

    test "creates a Try from a function value" do
      assert :value ==
        of!(fn -> :value end)
        |> reduce(&id/1, &unused/1)
    end

    test "destructures ok tuples into a new Try" do
      assert :value ==
        of!(fn -> {:ok, :value} end)
        |> reduce(&id/1, &unused/1)
    end
  end

  describe "map!/2" do
    test "raises ArgumentError when the first parameter is not a Try" do
      assert_raise ArgumentError, fn ->
        map!(:not_a_try, fn _ -> nil end)
      end
    end

    test "raises ArgumentError when the function evaluates to an error" do
      assert_raise ArgumentError, fn ->
        of!(fn -> :in end)
        |> map!(fn :in -> :error end)
      end
    end

    test "raises ArgumentError when the function evaluates to an {:error, _}" do
      assert_raise ArgumentError, fn ->
        of!(fn -> :in end)
        |> map!(fn :in -> {:error, nil} end)
      end
    end

    test "returns any given error" do
      assert {:tag, :no_value, :no_context} ==
        of(:tag, fn -> :error end)
        |> map!(&unused/1)
        |> reduce(&unused/1, &id/1)
    end

    test "creates a Try by applying a function to the value of a Try" do
      assert :out ==
        of!(fn -> :in end)
        |> map!(fn :in -> :out end)
        |> reduce(&id/1, &unused/1)
    end

    test "destructures ok tuples into a new Try" do
      assert :out ==
        of!(fn -> :in end)
        |> map!(fn :in -> {:ok, :out} end)
        |> reduce(&id/1, &unused/1)
    end
  end

  describe "map/3" do
    test "raises ArgumentError when the first parameter is not a Try" do
      assert_raise ArgumentError, fn ->
        map(:not_a_try, :tag, fn _ -> nil end)
      end
    end

    test "returns any given error" do
      assert {:tag, :no_value, :no_context} ==
        of(:tag, fn -> :error end)
        |> map(:ignored, fn _ -> nil end)
        |> reduce(&unused/1, &id/1)
    end

    test "creates a new Try by applying a function to the value of a Try" do
      assert :out ==
        of!(fn -> :in end)
        |> map(:tag, fn :in -> :out end)
        |> reduce(&id/1, &unused/1)
    end

    test "destructures ok tuples into a new Try" do
      assert :out ==
        of!(fn -> :in end)
        |> map(:tag, fn :in -> {:ok, :out} end)
        |> reduce(&id/1, &unused/1)
    end

    test "creates a Try from a function error" do
      assert {:tag, :in, :no_context} ==
        of!(fn -> :in end)
        |> map(:tag, fn :in -> :error end)
        |> reduce(&unused/1, &id/1)
    end

    test "desctructures error context into a new Try" do
      assert {:tag, :in, :context} ==
        of!(fn -> :in end)
        |> map(:tag, fn :in -> {:error, :context} end)
        |> reduce(&unused/1, &id/1)
    end
  end

  describe "reduce/3" do
    test "raises ArgumentError when the first parameter is not a Try" do
      assert_raise ArgumentError, fn ->
        reduce(:not_a_try, &unused/1, &unused/1)
      end
    end

    test "evaluates the Try's value to any term" do
      assert :out ==
        of!(fn -> :in end)
        |> reduce(
          fn :in -> :out end,
          &unused/1
        )
    end

    test "evaluates the Try's error to any term" do
      assert :out ==
        of!(fn -> :in end)
        |> map(:tag, fn :in -> {:error, :context} end)
        |> reduce(
          &unused/1,
          fn {:tag, :in, :context} -> :out end
        )
    end
  end
end

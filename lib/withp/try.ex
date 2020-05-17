defmodule Withp.Try do
  @moduledoc """
  A Try represents a computation which may result in an error. Try is designed
  to facilitate error-handling within the context of a streaming workflow, and
  in particular to address the shortcomings of `with` in this regard. Consider
  the following workflow:

  ```
      input = :some_term
      with {:ok, v1} <- f1(input), # should not fail
           {:ok, v2} <- f2(v1),    # might fail with {:error, :enoent}
           {:ok, v3} <- f3(v2)     # might fail with {:error, :enoent}
      do
        # do something with v3
      else
        # handle errors
      end
  ```

  One issue is that f1, f2, and f3 are treated the same way despite the fact
  that f1 should never product an error tuple. It's not clear without a code
  comment that this is the case.

  Another is that the `else` clause cannot uniquely determine the source of any
  `{:error, :enoent}` error because f2 and f3 both return one, and so we cannot
  trvially handle an exception from one differently than from the other.

  Both issues can be resolved, however, if we adopt the convention that any
  `{:error, _}` or `:error` result is "an error," and anything else is not. We
  can then define a higher-order function to add information to any error result
  such that they are distinguishable within the else clause. For example, we
  could decoarate an error from f1 or f2 with the name of the funciton that
  produced the error: `{:error, :f1, error}`. This is the approach Try takes:

  ```
      ok(:some_input)         # create an "ok" Try from an arbitrary term
        |> map_ok!(&f1/1)     # f1 should not fail, so we'll use map_ok!/1
        |> map_ok(:f2, &f2/1) # f2 might fail; tag the error with :f2
        |> map_ok(:f3, &f3/1) # f3 might fail; tag the error with :f3
        |> reduce(            # convert the Try to an aribtrary term
          fn result -> "it worked!" end,
          fn error -> case error
            e = {:f2_failed, input_to_f2, output_of_f2} -> "f2 broke!"
            e = {:f3_failed, input_to_f3, output_of_f3} -> "f3 broke!"
          end
        )
  ```
  """

  @doc """
  Create an `ok` Try from the given value.
  """
  def ok(value), do: {:ok, value}

  @doc """
  Create an `error` Try from the given tag, input, and output.
  """
  def error(tag, input, output), do: {:error, {tag, input, output}}

  @doc """
  Create an default `error` Try with a nil tag, input, and output.
  """
  def error, do: {:error, {nil, nil, nil}}

  @doc """
  Transform the value of an `ok` Try with the assumption that `ok_function`
  cannot fail. If `ok_function` evaluates to either `:error` or `{:error, _}`,
  map!/2 raises an ArgumentError.

  As with map/3, if the given Try is an `error`, ok_function is ignored and
  the `error` Try is returned.
  """
  def map_ok!(t, ok_function)

  def map_ok!(e = {:error, _}, _ok_function), do: e

  def map_ok!({:ok, value}, ok_function) do
    case ok_function.(value) do
      e = {:error, _} -> bad_ok_function(value, e)
      :error -> bad_ok_function(value, :error)
      result -> ok(result)
    end
  end

  def map_ok!(not_a_try, _ok_function) do
    bad_try(not_a_try)
  end

  defp bad_ok_function(input, output) do
    input = inspect(input)
    output = inspect(output)

    raise ArgumentError,
          "ok_function.(#{input}) evaluated to an illegal value: #{output}"
  end

  defp bad_try(not_a_try) do
    raise ArgumentError, "#{inspect(not_a_try)} is not a Try type"
  end

  @doc """
  Transform the value of an `ok` Try. If `ok_function` evaluates to either
  `:error` or `{:error, _}`, then an `error` Try is returned. Otherwise, an `ok`
  try holding the result is returned. If an `error` try is given, it is returned
  unmodified and `ok_function` is ignored.

  The `ok_function` may return any arbitrary value, though both `:error` and
  `{:error, _}` are special cases as previously described.
  """
  def map_ok(t, tag, ok_function)

  def map_ok(e = {:error, _}, _tag, _ok_function), do: e

  def map_ok({:ok, value}, tag, ok_function) do
    case ok_function.(value) do
      :error -> error(tag, value, nil)
      {:error, payload} -> error(tag, value, payload)
      result -> ok(result)
    end
  end

  def map_ok(not_a_try, _tag, _ok_function) do
    bad_try(not_a_try)
  end

  @doc """
  Transform an `ok` Try to another Try, or return an `error` if given an `error`
  Try.

  The `ok_function` must return a Try.
  """
  def flat_map(t, ok_function)

  def flat_map(e = {:error, _}, _ok_function), do: e

  def flat_map({:ok, value}, ok_function) do
    case ok_function.(value) do
      ok = {:ok, _} -> ok
      err = {:error, _} -> err
      invalid -> bad_ok_function(value, invalid)
    end
  end

  def flat_map(not_a_try, _ok_function) do
    bad_try(not_a_try)
  end

  @doc """
  Evaluate a Try into any arbitrary term. If the given Try is an `ok` Try, the
  the `ok_function` will handle evaluation. Otherwise, the `error_function`
  will. The result of either function is returned unchanged.
  """
  def reduce(t, ok_function, error_function) do
    case t do
      {:ok, value} -> ok_function.(value)
      {:error, error} -> error_function.(error)
      not_a_try -> bad_try(not_a_try)
    end
  end
end

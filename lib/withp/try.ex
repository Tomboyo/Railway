defmodule Withp.Try do
  @moduledoc """
  The Try functor combines functions which may produce errors of the form
  `:error` or `{:error, _}` into a pipeline. Computation short-circuits when an
  error is returned such that functions between the point of failure and the
  point of error-handling are ignored. This is similar to the `with` construct
  except that a Try can tell apart otherwise identical `:error` atoms returned
  by different functions to indicate different errors, and can handle them
  contextually.

  ## Example use case

  Consider the following workflow using `with`:

  ```
      with {:ok, v1} <- f1(),   # should not fail
           {:ok, v2} <- f2(v1), # might fail with {:error, :enoent}
           {:ok, v3} <- f3(v2)  # might fail with {:error, :enoent}
      do
        # do something with v3
      else
        # handle errors
      end
  ```

  There are two issues with this example:
  
  1. `f1` should _always_ match its pattern, but we lack a way to express this
     directly in the code. We can resort to code comments, but those tend to
     become wrong over time.
  2. `f2` and `f3` return the same value when they fail. The `else` clause
     cannot determine the source of any `{:error, :enoent}` value and therefore
     cannot handle an error from `f2` _differently_ than an error from `f3`.

  A Try workflow handles this more gracefully. We use `of/2` and `of!/1` to
  begin a workflow, `map/3` and `map!/2` to operate on data, and `reduce/3` to
  evaluate the workflow to any term. The "bang" variant functions `of!/1` and
  `map!/2` indicate that functions we give them can never return an error. The
  normal variants "contextualize" function errors by tagging them with locally-
  unique atoms that we can pattern-match later on in `reduce/3`:
  
  ```
      of!(&f1/0)
        |> map(:f2_error, &f2/1)
        |> map(:f3_error, &f3/1)
        |> reduce(
          fn result -> "it worked!" end,
          fn error ->
            case error do
              {:f2_error, _value_of_try, _error_context} -> "f2 broke!"
              {:f3_error, _value_of_try, _error_context} -> "f3 broke!"
            end
          end
        )
  ```

  Try treats both structured errors of the form `{:error, _context}` and
  unstructured errors `:error` as errors. All other values are considered
  normal. The first error causes a Try workflow to short-circuit, skipping all
  remaining `map` operations and evaluating the `reduce/3` step immediately.
  When an error value is encountered, the value of the try and the context part
  of the error (if any) is recorded and passed to the error callback of
  `reduce/3`.

  ## Considerations

  Refrain from using Try as a return type in any function. Error tags are very
  context-sensitive; they are easiest to pattern-match in the `reduce` step when
  they are on-screen, within the same function. Moreover, any attempt to re-use
  tags in shared functions is likely to encounter problems with tag overloading,
  which is essentially the problem with `with` that Try tries to address. Thus,
  treat a Try as a means of composition and evaluation, not as a value in and of
  itself.

  The reader may be perplexed to learn that there is no `flat_map` function, and
  yet `map` actually destructures `{:ok, value} | {:error, context}` types.
  Usually destructuring is the domain of `flat_map` functions. There are two
  reasons this is not so for Try:
  
  The first is that `flat_map` also tends to destructure self-similar values,
  and in the case of `{:ok, value} | {:error, context}` we are not dealing with
  another member of the Try type.

  The second is because some standard library functions like `Keyword.fetch/2`
  return values like `{:ok, value} | :error`, compositions of both structured
  and unstructured values. We may have used `flat_map` for specifically those
  functions which returned a structured result type if there was no such
  interleaving.
  """

  @no_value :no_value
  @no_context :no_context

  def of(tag, function) do
    case function.() do
      :error -> error(tag, @no_value, :no_context)
      {:error, context} -> error(tag, @no_value, context)
      {:ok, value} -> ok(value)
      value -> ok(value)
    end
  end

  def of!(function) do
    case function.() do
      :error ->
        raise ArgumentError, "of!/1 callback evaluated to :error"
      e = {:error, _context} ->
        raise ArgumentError, "of!/1 callback evaluated to #{inspect(e)}"
      {:ok, value} -> ok(value)
      value -> ok(value)
    end
  end

  defp ok(value), do: {:ok, value}
  defp error(tag, input, output), do: {:error, {tag, input, output}}

  @doc """
  Like `map/3`, apply a function to the value of a Try, but with the assumption
  that the function _should not_ return an error. If the function does so,
  `map!/2` raises an ArgumentError.
  """
  def map!(t, ok_function)

  def map!(e = {:error, {_, _, _}}, _ok_function), do: e

  def map!({:ok, value}, ok_function) do
    case ok_function.(value) do
      :error -> raise ArgumentError,
        "map!/2 callback evaluated to :error given #{inspect(value)}"
      e = {:error, _} -> raise ArgumentError,
        "map!/2 callback evaluated to #{inspect(e)} given #{inspect(value)}"
      {:ok, value} -> ok(value)
      result -> ok(result)
    end
  end

  def map!(not_a_try, _ok_function) do
    bad_try(not_a_try)
  end

  defp bad_try(not_a_try) do
    raise ArgumentError, "not a Try: #{inspect(not_a_try)}"
  end

  @doc """
  Apply a function to the value of a Try, returning a new Try with the result of
  the function, which may be an error value.

  `map/3` ignores its arguments if the given try has already encountered an
  error. The Try "short-circuits" upon the first occurence of any error value.

  The function may return an arbitrary value, which will become the value of the
  new Try. However, `:error` and `{:error, reason}` values are special cases.
  When either is returned, subsequent map operations short-circuit. Errors are
  recorded within the Try and may be handled within `reduce/3`.

  ## Examples

      iex> Withp.Try.of!(fn -> :input end)
      iex> |> Withp.Try.map(:my_tag, fn :input -> :output end)
      iex> |> Withp.Try.reduce(
      iex>     fn :output -> "Success!" end,
      iex>     fn e = {:my_tag, _try_value, _context} -> e end
      iex> )
      "Success!"

      iex> Withp.Try.of!(fn -> :input end)
      iex> |> Withp.Try.map(:my_tag, fn :input -> {:error, "oops!"} end)
      iex> |> Withp.Try.reduce(
      iex>     fn :output -> "Success!" end,
      iex>     fn e = {:my_tag, _try_value, _context} -> e end
      iex> )
      {:my_tag, :input, "oops!"}
  """
  def map(t, tag, ok_function)

  def map(e = {:error, {_, _, _}}, _tag, _ok_function), do: e

  def map({:ok, value}, tag, ok_function) do
    case ok_function.(value) do
      :error -> error(tag, value, @no_context)
      {:error, context} -> error(tag, value, context)
      {:ok, value} -> ok(value)
      result -> ok(result)
    end
  end

  def map(not_a_try, _tag, _ok_function) do
    bad_try(not_a_try)
  end

  @doc """
  Evaluate a Try into any arbitrary term.
  
  If the Try completed normally, then `value_function` is applied to the value
  of the Try. Otherwise, `error` function is applied the the error triple held
  by the Try.

  The error triple takes the form `{tag, value, context}`. The tag component is
  whatever tag atom was passed to the `of` or `map` function which encountered
  the error. The optional value component is takes the value of the Try when the
  error was encountered, if the Try had a value:

  * If the error was encountered by a `map` callback, it is the parameter passed
    to that callback.
  * If the error was encountered by an `of` callback, it defaults to
    `:no_value`.

  Finally, the optional context component is that of the encountered error, if
  the error contained a context payload:

  * If the error took the form `{:error, v}`, then context takes the value of
    `v`.
  * If the error was just `:error`, then context defaults to `:no_context`.

  The result of the applied function is returned directly.

  ## Examples

      iex> Withp.Try.of!(fn -> :value end)
      iex> |> Withp.Try.reduce(
      iex>     fn _okay  -> :okay end,
      iex>     fn _error -> :error end
      iex> )
      :okay

      iex> Withp.Try.of!(fn -> :value end)
      iex> |> Withp.Try.map(:tag, fn :value -> {:error, "oops!"} end)
      iex> |> Withp.Try.reduce(
      iex>     fn _okay -> :okay end,
      iex>     fn {:tag, value, context} -> {value, context} end
      iex> )
      {:value, "oops!"}
  """
  def reduce(t, value_function, error_function) do
    case t do
      {:ok, value} -> value_function.(value)
      {:error, error = {_, _, _}} -> error_function.(error)
      not_a_try -> bad_try(not_a_try)
    end
  end
end

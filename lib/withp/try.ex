defmodule Withp.Try do
  @moduledoc """
  The Try monad combines functions which may produce errors of the form `:error`
  or `{:error, _}` into a pipeline. Computation short-circuits when an error is
  returned such that functions between the point of failure and the point of
  error-handling are ignored. This is similar to the `with` construct except
  that a Try can tell apart otherwise identical `:error` atoms returned by
  different functions to indicate different errors, and can handle them
  contextually.

  Try is the sum of two states, Ok and Error. An Ok contains a value which
  can be "mutated" by the `map` and `flat_map` functions. An Error contains an
  "immutable" triple `{tag, input, output}` of a _tag_ that uniquely identifies
  the error within the context of a Try pipeline, the _input_ parameters to the
  function that evaluated to an Error, and the _output_ from that function.
  The `output` may be `nil` in the case of a function that simply returns
  `:error`, or it may contain the contents of an `{:error, _}` tuple.

  ## Example use case

  Consider the following workflow using `with`:

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

  There are two issues with this example:
  
  1. `f1` should _always_ match its pattern, but we lack a way to express this
     directly in the code. We can resort to code comments, but those tend to
     become wrong over time.
  2. `f2` and `f3` return the same value when they fail. The `else` clause
     cannot determine the source of any `{:error, :enoent}` value and therefore
     cannot handle an error from `f2` _differently_ than an error from `f3`.

  A Try workflow handles this more gracefully. We use `map!/2` to indicate that
  a given function should never fail, and `map/3` to "lift" error-returning
  functions into the Try workflow, tagging their errors with locally unique
  atoms that we can pattern-match later on:
  
  ```
      ok(:some_input)
        |> map!(&f1/1)
        |> map(:f2_error, &f2/1)
        |> map(:f3_error, &f3/1)
        |> reduce(
          fn result -> "it worked!" end,
          fn error ->
            case error do
              {:f2_error, _input_to_f2, _output_of_f2} -> "f2 broke!"
              {:f3_error, _input_to_f3, _output_of_f3} -> "f3 broke!"
            end
          end
        )
  ```

  In the example above we start our pipeline with `ok/1`, which creates an Ok
  from any term, and we end our pipline with `reduce/3`, which digests the Try
  into a String. `reduce/3` lets us pattern-match the distinct tags we
  introduced ad-hoc with `map/3`.
  """

  @doc """
  Create an Ok of the given value.
  """
  def ok(value), do: {:ok, value}

  @doc """
  Create an Error of the given tag, input, and output.

  * `tag` is simply a term to pattern-match with. It should be unique within the
    context of a single Try pipeline. Typically this is an atom.
  * `input` is the input parameters to the function which produced the Error.
  * `output` is the `reason` component of an `{:error, reason}` tuple returned
    by the function which produced the Error. If the function returned an
    unstructured error like `:error`, this is conventially left `nil`.
  """
  def error(tag, input, output), do: {:error, {tag, input, output}}

  @doc """
  Create a default Error with a `nil` tag, input, and output, equivalent to
  `error(nil, nil, nil)`. This function is intended for test cases and its use
  is cautioned against elsewhere. Note that `error/0` is no different than an
  unadorned `:error`, which defeats its purpose in most contexts.
  """
  def error, do: {:error, {nil, nil, nil}}

  @doc """
  Like `map/3`, apply a function to the contents of an Ok, but with the
  assumption that the function _should not_ return an error. If the function
  does so, `map!/2` raises an ArgumentError.
  """
  def map!(t, ok_function)

  def map!(e = {:error, _}, _ok_function), do: e

  def map!({:ok, value}, ok_function) do
    case ok_function.(value) do
      e = {:error, _} -> bad_ok_function(value, e)
      :error -> bad_ok_function(value, :error)
      result -> ok(result)
    end
  end

  def map!(not_a_try, _ok_function) do
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
  Apply a function to the content of an Ok, returning a new Ok with the result
  or else an Error.

  Like many Try functions, `map/3` returns `t` if `t` is an Error. Only if `t`
  is Ok does `map/3` apply the given function.

  The function may return an arbitrary value, which will become the content of
  the new Ok. However, `:error` and `{:error, reason}` are special cases. When
  either is returned, `map/3` evaluates to an Error:
    * If `:error` is returned and the Ok's contents are `content`, then `map/3`
      evaluates to `error(tag, content, nil)`.
    * If `{:error, output}` is returned and the Ok's contents are `content`,
      then `map/3` evaluates to `error(tag, content, output)`.

  ## Examples

      iex> Withp.Try.ok(:input)
      iex> |> Withp.Try.map(:my_tag, fn :input -> :output end)
      iex> |> Withp.Try.reduce(
      iex>     fn :output -> "Success!" end,
      iex>     fn e = {:my_tag, _input, _output} -> e end
      iex> )
      "Success!"

      iex> Withp.Try.ok(:input)
      iex> |> Withp.Try.map(:my_tag, fn :input -> {:error, "oops!"} end)
      iex> |> Withp.Try.reduce(
      iex>     fn :output -> "Success!" end,
      iex>     fn e = {:my_tag, _input, _output} -> e end
      iex> )
      {:my_tag, :input, "oops!"}
  """
  def map(t, tag, ok_function)

  def map(e = {:error, _}, _tag, _ok_function), do: e

  def map({:ok, value}, tag, ok_function) do
    case ok_function.(value) do
      :error -> error(tag, value, nil)
      {:error, payload} -> error(tag, value, payload)
      result -> ok(result)
    end
  end

  def map(not_a_try, _tag, _ok_function) do
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
  Evaluate a Try into any arbitrary term.
  
  If `t` is an Ok, then `ok_function` is applies to the content of the Ok. If
  instead `t` is an Error, then `error_function` is applied to the error triple.
  `reduce/3` returns the result direclty.

  ## Examples

      iex> Withp.Try.ok(:content)
      iex> |> Withp.Try.reduce(
      iex>     fn okay  -> okay end,
      iex>     fn error -> error end
      iex> )
      :content

      iex> Withp.Try.error(:tag, :input, :output)
      iex> |> Withp.Try.reduce(
      iex>     fn okay -> okay end,
      iex>     fn error -> error end
      iex> )
      {:tag, :input, :output}
  """
  def reduce(t, ok_function, error_function) do
    case t do
      {:ok, value} -> ok_function.(value)
      {:error, error} -> error_function.(error)
      not_a_try -> bad_try(not_a_try)
    end
  end
end

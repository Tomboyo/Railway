defmodule Railway do
  defstruct [:fns, :v]

  @opaque t :: %__MODULE__{
            fns: [(any -> {:continue, any} | {:stop, any})],
            v: any
          }

  @type result :: {:ok, any} | {:error, any}

  @spec of_one(any) :: t
  def of_one(element) do
    %__MODULE__{fns: [], v: {:ok, element}}
  end

  @spec error(any) :: t
  def error(e) do
    %__MODULE__{fns: [], v: {:error, e}}
  end

  @spec map_ok(t, (any -> result)) :: t
  def map_ok(railway = %__MODULE__{fns: fns}, f) do
    mapper = fn
      {:ok, value} -> {:continue, require_result(f.(value))}
      error = {:error, _} -> {:continue, error}
    end

    %{railway | fns: [mapper | fns]}
  end

  @spec map_error(t, (any -> result)) :: t
  def map_error(railway = %__MODULE__{fns: fns}, f) do
    mapper = fn
      ok = {:ok, _} -> {:continue, ok}
      {:error, e} -> {:continue, result_to_error(f.(e))}
    end

    %{railway | fns: [mapper | fns]}
  end

  @spec on_ok_return(t, (any -> x)) :: x when x: any
  def on_ok_return(railway = %__MODULE__{fns: fns}, f) do
    returner = fn
      {:ok, v} -> {:stop, f.(v)}
      error = {:error, _} -> {:continue, error}
    end

    %{railway | fns: [returner | fns]}
  end

  @spec on_error_return(t, (any -> x)) :: x when x: any
  def on_error_return(railway = %__MODULE__{fns: fns}, f) do
    returner = fn
      ok = {:ok, _} -> {:continue, ok}
      {:error, e} -> {:stop, f.(e)}
    end

    %{railway | fns: [returner | fns]}
  end

  @spec eval(t) :: any
  def eval(%__MODULE__{fns: functions, v: value}) do
    eval(Enum.reverse(functions), value)
  end

  defp eval([next | rest], v) do
    case next.(v) do
      {:continue, v1} -> eval(rest, v1)
      {:stop, v1} -> v1
    end
  end

  defp eval([], _) do
    # We received a {:continue, _} signal from a non-terminal function, but
    # there are no more functions to apply.
    raise ArgumentError, "The last combinator must be terminal."
  end

  defp require_result(r = {:ok, _v}), do: r
  defp require_result(r = {:error, _e}), do: r

  defp result_to_error({:ok, v}), do: {:error, v}
  defp result_to_error({:error, e}), do: {:error, e}
end

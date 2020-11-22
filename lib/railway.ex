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

  @spec compose(t, (t -> x)) :: x when x: t
  def compose(flow, f) do
    f.(flow)
  end

  @spec map_ok(t, (any -> result)) :: t
  def map_ok(flow = %__MODULE__{fns: fns}, f) do
    mapper = fn x ->
      case x do
        {:ok, value} -> {:continue, require_result(f.(value))}
        r = {:error, _} -> {:continue, r}
      end
    end

    %{flow | fns: [mapper | fns]}
  end

  @spec map_error(t, (any -> result)) :: t
  def map_error(flow = %__MODULE__{fns: fns}, f) do
    mapper = fn x ->
      case x do
        {:error, e} -> {:continue, result_to_error(f.(e))}
        l = {:ok, _} -> {:continue, l}
      end
    end

    %{flow | fns: [mapper | fns]}
  end

  @spec on_ok_return(t, (any -> x)) :: x when x: any
  def on_ok_return(flow = %__MODULE__{fns: fns}, f) do
    returner = fn x ->
      case x do
        {:ok, v} -> {:stop, f.(v)}
        r = {:error, _} -> {:continue, r}
      end
    end

    %{flow | fns: [returner | fns]}
  end

  @spec on_error_return(t, (any -> x)) :: x when x: any
  def on_error_return(flow = %__MODULE__{fns: fns}, f) do
    returner = fn x ->
      case x do
        {:error, e} -> {:stop, f.(e)}
        l = {:ok, _} -> {:continue, l}
      end
    end

    %{flow | fns: [returner | fns]}
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
    raise "The last combinator must be terminal."
  end

  defp require_result(r = {:ok, _v}), do: r
  defp require_result(r = {:error, _e}), do: r

  defp result_to_error({:ok, v}), do: {:error, v}
  defp result_to_error({:error, e}), do: {:error, e}
end

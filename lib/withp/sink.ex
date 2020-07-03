defmodule Withp.Sink do
  defstruct [:f, :v]

  def from(value) do
    %__MODULE__{f: [], v: value}
  end

  def guard(sink, test, finisher)
  when is_function(test) and is_function(finisher) do
    %__MODULE__{
      f: [{:guard, test, finisher} | sink.f],
      v: sink.v
    }
  end

  def transform(sink, transform)
  when is_function(transform) do
    %__MODULE__{
      f: [{:transform, transform} | sink.f],
      v: sink.v
    }
  end

  def finish(sink) do
    eval(Enum.reverse(sink.f), sink.v)
  end

  defp eval([{:guard, test, finisher} | sink], acc) do
    if test.(acc) do
      finisher.(acc)
    else
      if sink == [] do
        raise "Terminal guards failed to match term: #{inspect(acc)}."
      else
        eval(sink, acc)
      end
    end
  end

  defp eval([{:transform, transform} | sink], acc) do
    acc = transform.(acc)
    if sink == [] do
      acc
    else
      eval(sink, acc)
    end
  end
end

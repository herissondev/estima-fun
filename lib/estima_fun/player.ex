defmodule EstimaFun.Player do
  defstruct [:id, :name, :score]

  def new(id, name) do
    %__MODULE__{id: id, name: name, score: 0}
  end
end

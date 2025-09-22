defmodule MySystemWeb.Math do
  use MySystemWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    assign(socket, number: "", operations: []) |> ok()
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="text-lg p-4 bg-base-300 rounded-lg">
        <form phx-submit="submit">
          <.input label="Input" type="number" name="number" value={@number} />
          <.button variant="primary">Calculate</.button>
        </form>

        <div class="mt-4">
          <div :for={operation <- @operations} data-operation>
            ∑(1..{operation.input}) = {operation.result}
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("submit", params, socket) do
    str_input = Map.fetch!(params, "number")

    operation =
      case Integer.parse(str_input) do
        :error -> outcome(str_input, "invalid input")
        {_number, rest} when byte_size(rest) > 0 -> outcome(str_input, "invalid input")
        # {number, ""} when number < 0 -> outcome(str_input, "invalid input")
        {number, ""} -> start_sum(number)
      end

    update(socket, :operations, &[operation | &1]) |> noreply()
  end

  @impl Phoenix.LiveView
  def handle_info({:sum, pid, result}, socket),
    do: set_result(socket, pid, result) |> noreply()

  def handle_info({:DOWN, _ref, :process, pid, _reason}, socket),
    do: set_result(socket, pid, :error) |> noreply()

  defp start_sum(number) do
    pid = MySystem.Math.sum(number)
    %{pid: pid, input: number, result: :calculating}
  end

  defp set_result(socket, pid, result) do
    update(socket, :operations, fn operations ->
      case Enum.split_with(operations, &match?(%{pid: ^pid, result: :calculating}, &1)) do
        {[operation], rest} -> [%{operation | result: result} | rest]
        _other -> operations
      end
    end)
  end

  defp outcome(input, result),
    do: %{pid: nil, input: input, result: result}
end

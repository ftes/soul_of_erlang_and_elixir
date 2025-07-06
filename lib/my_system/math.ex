defmodule MySystem.Math do
  use Parent.Supervisor

  def start_link(_arg),
    do: Parent.Supervisor.start_link([], name: __MODULE__)

  def sum(number) do
    caller = self()

    {:ok, pid} =
      Parent.Client.start_child(
        __MODULE__,
        %{
          start: {Task, :start_link, [fn -> calc_sum_and_send(caller, number) end]},
          restart: :temporary,
          ephemeral?: true,
          meta: caller
        }
      )

    Process.monitor(pid)
    pid
  end

  defp calc_sum_and_send(caller, n) do
    send(caller, {:sum, self(), calc_sum(n)})
  end

  defp calc_sum(13), do: raise("error")

  defp calc_sum(n), do: calc_sum(1, n, 0)
  defp calc_sum(from, from, sum), do: sum + from
  defp calc_sum(from, to, acc_sum), do: calc_sum(from + 1, to, acc_sum + from)

  # defp calc_sum(n), do: div(n * (n + 1), 2)
end

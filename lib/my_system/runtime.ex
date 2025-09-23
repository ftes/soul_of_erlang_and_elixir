defmodule Runtime do
  @moduledoc false
  def top(time \\ to_timeout(second: 1)) do
    wall_times = wall_times()
    initial_processes = processes()

    Process.sleep(time)

    final_processes =
      Enum.map(
        processes(),
        fn {pid, reds} ->
          prev_reds = Map.get(initial_processes, pid, 0)
          %{pid: pid, reds: reds - prev_reds}
        end
      )

    schedulers_usage = usage(wall_times) / :erlang.system_info(:schedulers_online)
    total_reds_delta = final_processes |> Stream.map(& &1.reds) |> Enum.sum()

    final_processes
    |> Enum.sort_by(& &1.reds, &>=/2)
    |> Stream.take(10)
    |> Enum.map(&%{pid: &1.pid, cpu: round(schedulers_usage * 100 * &1.reds / total_reds_delta)})
  end

  defp processes do
    for {pid, {:reductions, reds}} <-
          Stream.map(Process.list(), &{&1, Process.info(&1, :reductions)}),
        into: %{},
        do: {pid, reds}
  end

  def trace(pid) do
    fn ->
      :erlang.trace(pid, true, [:call])

      try do
        :erlang.trace(pid, true, [:call])
      rescue
        ArgumentError ->
          []
      else
        _ ->
          :erlang.trace_pattern({:_, :_, :_}, true, [:local])
          Process.send_after(self(), :stop_trace, to_timeout(second: 1))

          fn ->
            receive do
              {:trace, ^pid, :call, {mod, fun, args}} -> {mod, fun, args}
              :stop_trace -> :stop_trace
            end
          end
          |> Stream.repeatedly()
          |> Stream.take(50)
          |> Enum.take_while(&(&1 != :stop_trace))
      end
    end
    |> Task.async()
    |> Task.await()
  end

  def usage(previous_times) do
    new_times = wall_times()

    {actives, totals} =
      new_times
      |> Enum.filter(fn {id, _} ->
        id <= :erlang.system_info(:schedulers_online) or
          (id >= :erlang.system_info(:schedulers) + 1 and
             id <
               :erlang.system_info(:schedulers) + 1 +
                 :erlang.system_info(:dirty_cpu_schedulers_online))
      end)
      |> Enum.map(fn {scheduler_id, new_time} ->
        usage(new_time, Map.fetch!(previous_times, scheduler_id))
      end)
      |> Enum.unzip()

    total_processors =
      :erlang.system_info(:schedulers_online) + :erlang.system_info(:dirty_cpu_schedulers_online)

    min(
      total_processors * Enum.sum(actives) / Enum.sum(totals),
      :erlang.system_info(:schedulers_online)
    )
  end

  defp usage(new_time, previous_time), do: {new_time.active - previous_time.active, new_time.total - previous_time.total}

  def wall_times do
    :scheduler_wall_time
    |> :erlang.statistics()
    |> Map.new(fn {id, active_time, total_time} ->
      {id, %{active: active_time, total: total_time}}
    end)
  end
end

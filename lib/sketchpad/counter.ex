defmodule Sketchpad.Counter do
  use GenServer

  ## Client

  def inc(pid), do: GenServer.cast(pid, :inc)
  def dec(pid), do: GenServer.cast(pid, :dec)
  def val(pid) do
    GenServer.call(pid, :val)
  end

  ## Server
  def start_link(initial_count \\ 0) do
    GenServer.start_link(__MODULE__, initial_count)
  end

  def init(initial_count) do
    IO.puts "Starting with #{initial_count}"
    :timer.send_interval(500, :tick)
    {:ok, initial_count}
  end

  def handle_info(:tick, 0), do: raise "boom"
  def handle_info(:tick, count) do
    IO.puts "tick #{count}"
    {:noreply, count - 1}
  end

  def handle_cast(:inc, count) do
    {:noreply, count + 1}
  end

  def handle_cast(:dec, count) do
    {:noreply, count - 1}
  end

  def handle_call(:val, _from, count) do
    {:reply, count, count}
  end
end

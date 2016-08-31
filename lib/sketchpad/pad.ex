defmodule Sketchpad.Pad do
  use GenServer

  ## Client

  def find(pad_id) do
    case :global.whereis_name("pad:#{pad_id}") do
      pid when is_pid(pid) -> {:ok, pid}
      :undefined -> {:error, :undefined}
    end
  end

  def put_stroke(pid, pad_id, user_id, stroke) do
    :ok = GenServer.call(pid, {:stroke, user_id, stroke})
    Sketchpad.PadChannel.broadcast_stroke(
      pad_id,
      self(),
      user_id,
      stroke)
  end

  def clear(pid, pad_id) do
    GenServer.call(pid, :clear)
    Sketchpad.PadChannel.broadcast_clear(pad_id)
  end

  def render(pid) do
    GenServer.call(pid, :render)
  end

  def png_ack(user_id, encoded_img) do
    with {:ok, decoded_img} <- Base.decode64(encoded_img),
         {:ok, png_path} <- Briefly.create(),
         :ok <- File.write(png_path, decoded_img),
         {:ok, jpeg_path} <- Briefly.create(),
         args = ["-background", "white", "-flatten", png_path, "jpg:" <> jpeg_path],
         {_, 0} <- System.cmd("convert", args),
         {ascii, 0} <- System.cmd("jp2a", ["-i", jpeg_path]) do

      IO.puts ascii
      IO.puts ">>#{user_id}"

      {:ok, ascii}
    else
      _ -> :error
    end
  end

  ## Server
  def start_link(topic) do
    GenServer.start_link(__MODULE__, topic, name: {:global, topic})
  end

  defp schedule_png_request() do
    Process.send_after(self(), :request_png, 3_000)
  end

  def init("pad:" <> pad_id) do
    schedule_png_request()
    {:ok, %{users: %{}, pad_id: pad_id}}
  end

  def handle_info(:request_png, state) do
    case Sketchpad.Presence.list("pad:" <> state.pad_id) do
      users when map_size(users) === 0 -> :noop
      users ->
        {_, %{metas: [%{phx_ref: ref} | _]}} = Enum.random(users)
        Sketchpad.PadChannel.broadcast_request(state.pad_id, ref)
    end
    schedule_png_request()
    {:noreply, state}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state | users: %{}}}
  end

  def handle_call({:stroke, user_id, stroke}, _from, state) do
    {:reply, :ok, do_put_stroke(state, user_id, stroke)}
  end

  def handle_call(:render, _from, state) do
    {:reply, state.users, state}
  end

  defp do_put_stroke(%{users: users} = state, user_id, stroke) do
    users = Map.put_new(users, user_id, %{id: user_id, strokes: []})
    users = update_in(users, [user_id, :strokes], fn strokes ->
      [stroke | strokes]
    end)

    %{state | users: users}
  end
end

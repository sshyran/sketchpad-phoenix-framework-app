defmodule Sketchpad.PadChannel do
  use Sketchpad.Web, :channel
  alias Sketchpad.{Presence}

  intercept ["clear"]

  def join("pad:" <> _pad_id, _params, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    %{user_id: user_id} = socket.assigns
    {:ok, _ref} = Presence.track(socket, user_id, %{device: "browser"})
    push socket, "presence_state", Presence.list(socket)

    {:noreply, socket}
  end

  def handle_in("clear", _params, socket) do
    broadcast!(socket, "clear", %{})
    {:reply, :ok, socket}
  end

  def handle_in("stroke", data, socket) do
    broadcast_from!(socket, "stroke", %{
      user_id: socket.assigns.user_id,
      stroke: data
    })

    {:reply, :ok, socket}
  end

  def handle_out("clear", _, socket) do
    IO.inspect "Got clear"
    push socket, "clear", %{}
    {:noreply, socket}
  end
end

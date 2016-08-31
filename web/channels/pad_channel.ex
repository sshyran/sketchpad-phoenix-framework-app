defmodule Sketchpad.PadChannel do
  use Sketchpad.Web, :channel
  alias Sketchpad.{Pad, Presence, Endpoint}

  def broadcast_clear(pad_id) do
    Endpoint.broadcast!("pad:#{pad_id}", "clear", %{})
  end

  def broadcast_request(pad_id, ref) do
    Endpoint.broadcast!("pad:#{pad_id}:#{ref}", "pad_request", %{})
  end

  def broadcast_stroke(pad_id, from, user_id, stroke) do
    Endpoint.broadcast_from!(from, "pad:#{pad_id}", "stroke", %{
      user_id: user_id,
      stroke: stroke
    })
  end

  def join("pad:" <> pad_id, _params, socket) do
    send(self(), :after_join)
    {:ok, pad} = Pad.find(pad_id)

    socket =
      socket
      |> assign(:pad_id, pad_id)
      |> assign(:pad, pad)

    {:ok, socket}
  end

  alias Phoenix.Socket.Broadcast
  def handle_info(%Broadcast{event: "pad_request"}, socket) do
    push socket, "pad_request", %{}
    {:noreply, socket}
  end

  def handle_info(:after_join, socket) do
    %{pad: pad, user_id: user_id, pad_id: pad_id} = socket.assigns
    {:ok, ref} = Presence.track(socket, user_id, %{
      device: "browser"
    })
    :ok = Endpoint.subscribe("pad:#{pad_id}:#{ref}")
    push socket, "presence_state", Presence.list(socket)

    for {id, %{strokes: strokes}} <- Pad.render(pad) do
      for stroke <- Enum.reverse(strokes) do
        push socket, "stroke", %{user_id: id, stroke: stroke}
      end
    end

    {:noreply, socket}
  end

  def handle_in("clear", _params, socket) do
    :ok = Pad.clear(socket.assigns.pad, socket.assigns.pad_id)
    {:reply, :ok, socket}
  end

  def handle_in("stroke", data, socket) do
    %{user_id: user_id, pad: pad, pad_id: pad_id} = socket.assigns
    Pad.put_stroke(pad, pad_id, user_id, data)

    {:reply, :ok, socket}
  end

  def handle_in("pad_ack",
    %{"img" => "data:image/png;base64," <> img}, socket)
    when byte_size(img) < 5_000_000 do

    {:ok, ascii} = Pad.png_ack(socket.assigns.user_id, img)

    {:reply, :ok, socket}
  end
end

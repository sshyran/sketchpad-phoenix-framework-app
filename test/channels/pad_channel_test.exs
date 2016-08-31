defmodule Sketchpad.PadChannelTest do
  use Sketchpad.ChannelCase
  alias Sketchpad.{Pad, PadChannel}

  setup do
    {:ok, pad} = Pad.find("lobby")
    :ok = Pad.clear(pad, "lobby")
    socket = socket("pad:lobby", %{user_id: 123})
    {:ok, pad: pad, socket: socket}
  end

  test "receives strokes with active pad", %{pad: pad, socket: socket} do
    :ok = Pad.put_stroke(pad, "lobby", 123, %{points: [1,2,3,4]})

    assert {:ok, _, socket} =
           subscribe_and_join(socket, PadChannel, "pad:lobby", %{})

    assert_push "stroke",
      %{stroke: %{points: [1, 2, 3, 4]}, user_id: 123}
  end

  test "receives no strokes with empty pad", %{socket: socket} do
    assert {:ok, _, socket} =
           subscribe_and_join(socket, PadChannel, "pad:lobby", %{})

    refute_push "stroke", %{}
  end

  test "clears the pad", %{pad: pad, socket: socket} do
    :ok = Pad.put_stroke(pad, "lobby", 123, %{points: [1,2,3,4]})
    assert {:ok, _, socket} =
           subscribe_and_join(socket, PadChannel, "pad:lobby", %{})

    refute Pad.render(pad) == %{}
    _ref = push(socket, "clear", %{})
    assert_broadcast "clear", %{}
    assert Pad.render(pad) == %{}
  end
end

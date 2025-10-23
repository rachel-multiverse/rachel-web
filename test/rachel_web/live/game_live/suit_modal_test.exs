defmodule RachelWeb.GameLive.SuitModalTest do
  use RachelWeb.ConnCase

  import Phoenix.LiveViewTest

  alias RachelWeb.GameLive.SuitModal

  describe "render/1" do
    test "displays suit selection title" do
      html = render_component(SuitModal, id: "suit-modal")

      assert html =~ "Choose Suit for Ace"
    end

    test "displays hearts button" do
      html = render_component(SuitModal, id: "suit-modal")

      assert html =~ "♥"
      assert html =~ "Hearts"
      assert html =~ "phx-value-suit=\"hearts\""
    end

    test "displays diamonds button" do
      html = render_component(SuitModal, id: "suit-modal")

      assert html =~ "♦"
      assert html =~ "Diamonds"
      assert html =~ "phx-value-suit=\"diamonds\""
    end

    test "displays clubs button" do
      html = render_component(SuitModal, id: "suit-modal")

      assert html =~ "♣"
      assert html =~ "Clubs"
      assert html =~ "phx-value-suit=\"clubs\""
    end

    test "displays spades button" do
      html = render_component(SuitModal, id: "suit-modal")

      assert html =~ "♠"
      assert html =~ "Spades"
      assert html =~ "phx-value-suit=\"spades\""
    end

    test "all buttons trigger play_cards event" do
      html = render_component(SuitModal, id: "suit-modal")

      # Should have 4 play_cards buttons (one for each suit)
      assert html =~ ~s(phx-click="play_cards")

      # Count occurrences
      play_cards_count =
        html
        |> String.split(~s(phx-click="play_cards"))
        |> length()
        |> Kernel.-(1)

      assert play_cards_count == 4
    end

    test "has close modal functionality" do
      html = render_component(SuitModal, id: "suit-modal")

      assert html =~ "phx-click=\"close_suit_modal\""
      assert html =~ "phx-click-away=\"close_suit_modal\""
    end

    test "uses modal overlay styling" do
      html = render_component(SuitModal, id: "suit-modal")

      assert html =~ "fixed inset-0"
      assert html =~ "bg-black bg-opacity-50"
      assert html =~ "z-50"
    end

    test "hearts and diamonds use red styling" do
      html = render_component(SuitModal, id: "suit-modal")

      # Count red button classes
      red_count =
        html
        |> String.split("bg-red-600")
        |> length()
        |> Kernel.-(1)

      assert red_count == 2
    end

    test "clubs and spades use dark styling" do
      html = render_component(SuitModal, id: "suit-modal")

      # Count dark button classes
      dark_count =
        html
        |> String.split("bg-gray-800")
        |> length()
        |> Kernel.-(1)

      assert dark_count == 2
    end
  end
end

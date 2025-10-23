defmodule RachelWeb.TutorialLiveTest do
  use RachelWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "Tutorial page" do
    test "renders tutorial page successfully", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tutorial")

      assert html =~ "Rachel Card Game Tutorial"
      assert html =~ "Learn the rules and master the game"
    end

    test "displays all 9 chapters in sidebar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tutorial")

      # Check all chapter titles are present
      assert html =~ "Basic Play"
      assert html =~ "Special Cards: 2s"
      assert html =~ "Special Cards: 7s"
      assert html =~ "Special Cards: Jacks"
      assert html =~ "Special Cards: Queens"
      assert html =~ "Special Cards: Aces"
      assert html =~ "Card Stacking"
      assert html =~ "Mandatory Play Rule"
      assert html =~ "Winning the Game"
    end

    test "starts with Basic Play chapter selected by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      # Should show Basic Play chapter title
      assert view |> element(".chapter-title", "Basic Play") |> has_element?()
    end

    test "can navigate to different chapters via sidebar", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      # Click on Special Cards: 2s chapter (use .chapter-nav-button to target only sidebar)
      view
      |> element(".chapter-nav-button[phx-value-chapter='special_2s']")
      |> render_click()

      # Verify chapter title changed
      assert view |> element(".chapter-title", "Special Cards: 2s") |> has_element?()
    end

    test "displays correct content for all chapters", %{conn: conn} do
      chapters = [
        {:basic_play, "Basic Play"},
        {:special_2s, "Special Cards: 2s"},
        {:special_7s, "Special Cards: 7s"},
        {:special_jacks, "Special Cards: Jacks"},
        {:special_queens, "Special Cards: Queens"},
        {:special_aces, "Special Cards: Aces"},
        {:stacking, "Card Stacking"},
        {:mandatory_play, "Mandatory Play Rule"},
        {:winning, "Winning the Game"}
      ]

      {:ok, view, _html} = live(conn, ~p"/tutorial")

      for {chapter_id, expected_title} <- chapters do
        view
        |> element(".chapter-nav-button[phx-value-chapter='#{chapter_id}']")
        |> render_click()

        assert view |> element(".chapter-title", expected_title) |> has_element?(),
               "Chapter #{chapter_id} should display title: #{expected_title}"
      end
    end

    test "highlights currently selected chapter in sidebar", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/tutorial")

      # First chapter should be highlighted (has bg-green-600 class)
      assert html =~ ~r/phx-value-chapter="basic_play"[^>]*bg-green-600/

      # Navigate to another chapter
      html =
        view
        |> element("button[phx-value-chapter='special_7s']")
        |> render_click()

      # New chapter should be highlighted
      assert html =~ ~r/phx-value-chapter="special_7s"[^>]*bg-green-600/
    end
  end

  describe "Chapter navigation" do
    test "shows 'Next' button on first chapter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tutorial")

      assert html =~ "Next: Special Cards: 2s"
      refute html =~ "Previous:"
    end

    test "shows both 'Previous' and 'Next' buttons on middle chapters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      # Navigate to middle chapter (Special Cards: Jacks - chapter 4)
      html =
        view
        |> element("button[phx-value-chapter='special_jacks']")
        |> render_click()

      assert html =~ "Previous: Special Cards: 7s"
      assert html =~ "Next: Special Cards: Queens"
    end

    test "shows 'Previous' and 'Start Playing' on last chapter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      # Navigate to last chapter
      html =
        view
        |> element("button[phx-value-chapter='winning']")
        |> render_click()

      assert html =~ "Previous: Mandatory Play Rule"
      assert html =~ "Start Playing!"
      refute html =~ "Next:"
    end

    test "'Next' button navigates to next chapter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      # Should start on Basic Play
      assert view |> element(".chapter-title", "Basic Play") |> has_element?()

      # Click Next button (use .nav-button class to target navigation button specifically)
      view
      |> element(".nav-button[phx-value-chapter='special_2s']")
      |> render_click()

      # Should now be on Special Cards: 2s
      assert view |> element(".chapter-title", "Special Cards: 2s") |> has_element?()
    end

    test "'Previous' button navigates to previous chapter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      # Navigate to chapter 3
      view
      |> element(".chapter-nav-button[phx-value-chapter='special_7s']")
      |> render_click()

      # Click Previous button (should go to chapter 2)
      view
      |> element(".nav-button[phx-value-chapter='special_2s']")
      |> render_click()

      # Should now be on Special Cards: 2s
      assert view |> element(".chapter-title", "Special Cards: 2s") |> has_element?()
    end
  end

  describe "Card examples" do
    test "displays card examples in chapters", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tutorial")

      # Basic Play chapter should show example cards
      assert html =~ ~r/class="card/
      # Should show suit symbols
      assert html =~ "♥" or html =~ "♦" or html =~ "♣" or html =~ "♠"
    end

    test "shows multiple card examples in stacking chapter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      html =
        view
        |> element("button[phx-value-chapter='stacking']")
        |> render_click()

      # Should show multiple cards in examples
      card_count = html |> String.split(~r/class="card/) |> length() |> Kernel.-(1)
      assert card_count >= 3, "Stacking chapter should show multiple card examples"
    end

    test "shows black and red jacks in jacks chapter", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      html =
        view
        |> element("button[phx-value-chapter='special_jacks']")
        |> render_click()

      # Should explain black jacks (spades and clubs)
      assert html =~ "Black Jacks"
      assert html =~ "Red Jacks"
      assert html =~ "♠" or html =~ "♣"
      assert html =~ "♥" or html =~ "♦"
    end
  end

  describe "Tip boxes" do
    test "displays tip boxes with important information", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      html =
        view
        |> element(".chapter-nav-button[phx-value-chapter='special_2s']")
        |> render_click()

      # Should have tip boxes
      assert html =~ ~r/class="tip-box/
      assert html =~ "Attack Strategy" or html =~ "Important"
    end

    test "mandatory play chapter shows warning tip boxes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      html =
        view
        |> element("button[phx-value-chapter='mandatory_play']")
        |> render_click()

      assert html =~ "tip-box"
      assert html =~ "When You CAN Draw" or html =~ "When You CANNOT Draw"
    end

    test "winning chapter shows success tip box", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      html =
        view
        |> element(".chapter-nav-button[phx-value-chapter='winning']")
        |> render_click()

      assert html =~ "You&#39;re Ready!"
      assert html =~ "tip-box-success"
    end
  end

  describe "Accessibility" do
    test "tutorial page is publicly accessible without authentication", %{conn: conn} do
      # Should not require login
      {:ok, _view, _html} = live(conn, ~p"/tutorial")
    end

    test "sidebar has proper heading structure", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tutorial")

      # Should have h1 for main title
      assert html =~ ~r/<h1[^>]*>Rachel Card Game Tutorial<\/h1>/
      # Should have h2 for sidebar
      assert html =~ ~r/<h2[^>]*>Chapters<\/h2>/
    end

    test "chapters have proper heading hierarchy", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tutorial")

      # Chapter title should be h2
      assert html =~ ~r/<h2[^>]*chapter-title[^>]*>/
      # Section titles should be h3
      assert html =~ ~r/<h3[^>]*section-title[^>]*>/
    end
  end

  describe "Integration" do
    test "'Start Playing' link on last chapter redirects to lobby", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/tutorial")

      # Navigate to last chapter
      view
      |> element("button[phx-value-chapter='winning']")
      |> render_click()

      # The lobby link should be present
      assert view
             |> element("a[href='/lobby']")
             |> has_element?()
    end

    test "tutorial link in navigation is present", %{conn: conn} do
      # Get tutorial page to check navigation
      {:ok, _view, html} = live(conn, ~p"/tutorial")

      # Should have tutorial link in navigation
      assert html =~ ~r/href="\/tutorial"/
      assert html =~ "Tutorial"
    end
  end
end

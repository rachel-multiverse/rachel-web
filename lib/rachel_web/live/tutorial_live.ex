defmodule RachelWeb.TutorialLive do
  use RachelWeb, :live_view

  alias Rachel.Game.Card

  @chapters [
    %{id: :basic_play, title: "Basic Play", order: 1},
    %{id: :special_2s, title: "Special Cards: 2s", order: 2},
    %{id: :special_7s, title: "Special Cards: 7s", order: 3},
    %{id: :special_jacks, title: "Special Cards: Jacks", order: 4},
    %{id: :special_queens, title: "Special Cards: Queens", order: 5},
    %{id: :special_aces, title: "Special Cards: Aces", order: 6},
    %{id: :stacking, title: "Card Stacking", order: 7},
    %{id: :mandatory_play, title: "Mandatory Play Rule", order: 8},
    %{id: :winning, title: "Winning the Game", order: 9}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:selected_chapter, :basic_play)
     |> assign(:chapters, @chapters)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="tutorial-container min-h-screen bg-green-900 p-4">
      <div class="max-w-7xl mx-auto">
        <div class="tutorial-header mb-8">
          <h1 class="text-4xl font-bold text-white mb-2">Rachel Card Game Tutorial</h1>
          <p class="text-green-100">Learn the rules and master the game</p>
        </div>

        <div class="tutorial-layout">
          <!-- Chapter Navigation Sidebar -->
          <nav class="tutorial-sidebar">
            <h2 class="text-xl font-bold text-white mb-4">Chapters</h2>
            <ul class="space-y-2">
              <%= for chapter <- @chapters do %>
                <li>
                  <button
                    phx-click="select_chapter"
                    phx-value-chapter={chapter.id}
                    class={[
                      "chapter-nav-button w-full text-left px-4 py-3 rounded-lg transition-all",
                      if(@selected_chapter == chapter.id,
                        do: "bg-green-600 text-white font-semibold",
                        else: "bg-green-800 text-green-100 hover:bg-green-700"
                      )
                    ]}
                  >
                    <span class="chapter-number"><%= chapter.order %>.</span>
                    <%= chapter.title %>
                  </button>
                </li>
              <% end %>
            </ul>
          </nav>

          <!-- Chapter Content Area -->
          <main class="tutorial-content">
            <%= render_chapter(@selected_chapter, assigns) %>

            <!-- Navigation Buttons -->
            <div class="chapter-navigation flex justify-between mt-8 pt-6 border-t-2 border-green-700">
              <%= if previous_chapter = get_previous_chapter(@selected_chapter) do %>
                <button
                  phx-click="select_chapter"
                  phx-value-chapter={previous_chapter.id}
                  class="nav-button bg-green-700 hover:bg-green-600 text-white px-6 py-3 rounded-lg transition-all"
                >
                  ← Previous: <%= previous_chapter.title %>
                </button>
              <% else %>
                <div></div>
              <% end %>

              <%= if next_chapter = get_next_chapter(@selected_chapter) do %>
                <button
                  phx-click="select_chapter"
                  phx-value-chapter={next_chapter.id}
                  class="nav-button bg-green-700 hover:bg-green-600 text-white px-6 py-3 rounded-lg transition-all"
                >
                  Next: <%= next_chapter.title %> →
                </button>
              <% else %>
                <.link
                  navigate={~p"/lobby"}
                  class="nav-button bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg transition-all inline-block"
                >
                  Start Playing! →
                </.link>
              <% end %>
            </div>
          </main>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_chapter", %{"chapter" => chapter_id}, socket) do
    chapter_atom = String.to_existing_atom(chapter_id)
    {:noreply, assign(socket, :selected_chapter, chapter_atom)}
  end

  # Chapter rendering functions
  defp render_chapter(:basic_play, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Basic Play</h2>

      <p class="chapter-text">
        Rachel is a strategic card game where your goal is to be the first player to get rid of all your cards.
        On your turn, you must play a card that matches either the <strong>suit</strong> or <strong>rank</strong>
        of the top card on the discard pile.
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Top Card on Discard Pile</h3>
          <div class="flex justify-center gap-4">
            <.card_display card={Card.new(:hearts, 7)} />
          </div>
        </div>

        <div class="example-group">
          <h3 class="example-title">Valid Plays - Match Suit or Rank</h3>
          <div class="flex justify-center gap-4 flex-wrap">
            <div class="example-card">
              <.card_display card={Card.new(:hearts, 3)} />
              <p class="example-label">Same suit (♥)</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:clubs, 7)} />
              <p class="example-label">Same rank (7)</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:hearts, 12)} />
              <p class="example-label">Same suit (♥)</p>
            </div>
          </div>
        </div>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">💡 Important Rule</h4>
        <p>
          If you cannot play a card that matches, you must draw a card from the deck.
          You can only draw when you have no valid plays.
        </p>
      </div>

      <h3 class="section-title">How Turns Work</h3>
      <ol class="tutorial-list">
        <li>Check the top card on the discard pile</li>
        <li>Play a card that matches the suit OR rank</li>
        <li>If you can't play, draw one card from the deck</li>
        <li>Play passes to the next player</li>
      </ol>
    </div>
    """
  end

  defp render_chapter(:special_2s, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Special Cards: 2s</h2>

      <p class="chapter-text">
        Playing a <strong>2</strong> is an attack! The next player must draw 2 cards and lose their turn,
        unless they also have a 2 to play. Multiple 2s can be stacked to increase the penalty.
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Attack with a 2</h3>
          <div class="flex justify-center gap-4">
            <.card_display card={Card.new(:diamonds, 2)} />
          </div>
          <p class="example-description">Next player draws 2 cards</p>
        </div>
      </div>

      <h3 class="section-title">Stacking 2s</h3>
      <p class="chapter-text">
        If you're under attack from a 2, you can play your own 2 instead of drawing.
        This passes the attack to the next player and increases the penalty by 2 more cards!
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Stacking Example</h3>
          <div class="flex justify-center gap-4 flex-wrap">
            <div class="example-card">
              <.card_display card={Card.new(:clubs, 2)} />
              <p class="example-label">Player 1: Draw 2</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:hearts, 2)} />
              <p class="example-label">Player 2: Draw 4</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:spades, 2)} />
              <p class="example-label">Player 3: Draw 6!</p>
            </div>
          </div>
        </div>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">⚡ Attack Strategy</h4>
        <p>
          Save your 2s for strategic moments! They're powerful defensive cards when you're under attack,
          and devastating offensive cards when played at the right time.
        </p>
      </div>
    </div>
    """
  end

  defp render_chapter(:special_7s, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Special Cards: 7s</h2>

      <p class="chapter-text">
        Playing a <strong>7</strong> skips the next player's turn. Like 2s, multiple 7s can be stacked
        to skip multiple players!
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Skip with a 7</h3>
          <div class="flex justify-center gap-4">
            <.card_display card={Card.new(:clubs, 7)} />
          </div>
          <p class="example-description">Next player is skipped</p>
        </div>
      </div>

      <h3 class="section-title">Stacking 7s</h3>
      <p class="chapter-text">
        When you're about to be skipped, you can play your own 7 to pass the skip to the next player.
        Stack enough 7s and you can skip multiple opponents!
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Stacking Example</h3>
          <div class="flex justify-center gap-4 flex-wrap">
            <div class="example-card">
              <.card_display card={Card.new(:diamonds, 7)} />
              <p class="example-label">Skip 1 player</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:hearts, 7)} />
              <p class="example-label">Skip 2 players</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:spades, 7)} />
              <p class="example-label">Skip 3 players!</p>
            </div>
          </div>
        </div>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">🎯 Tactical Tip</h4>
        <p>
          Use 7s to skip players who are close to winning, or to defend yourself when you're about to be skipped.
          In a 4-player game, three stacked 7s will bring the turn back to you!
        </p>
      </div>
    </div>
    """
  end

  defp render_chapter(:special_jacks, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Special Cards: Jacks</h2>

      <p class="chapter-text">
        Jacks are the most powerful cards in Rachel, but their effect depends on their color!
      </p>

      <h3 class="section-title">Black Jacks (♠♣) - Attack Cards</h3>
      <p class="chapter-text">
        Black Jacks are devastating attack cards. The next player must draw <strong>5 cards</strong>
        and lose their turn!
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Black Jack Attack</h3>
          <div class="flex justify-center gap-4">
            <.card_display card={Card.new(:spades, 11)} />
            <.card_display card={Card.new(:clubs, 11)} />
          </div>
          <p class="example-description">Next player draws 5 cards!</p>
        </div>
      </div>

      <h3 class="section-title">Red Jacks (♥♦) - Cancel Cards</h3>
      <p class="chapter-text">
        Red Jacks are defensive cards that cancel Black Jack attacks! Playing a Red Jack
        reduces the attack penalty by 5 cards. If the attack is exactly 5 cards, it's completely negated.
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Canceling an Attack</h3>
          <div class="flex justify-center gap-4 flex-wrap">
            <div class="example-card">
              <.card_display card={Card.new(:spades, 11)} />
              <p class="example-label">Draw 5 cards</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:hearts, 11)} />
              <p class="example-label">Attack canceled!</p>
            </div>
          </div>
        </div>
      </div>

      <h3 class="section-title">Stacking Jacks</h3>
      <p class="chapter-text">
        Black Jacks can be stacked together for massive attacks. Red Jacks reduce the total by 5.
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Complex Jack Stacking</h3>
          <div class="flex justify-center gap-4 flex-wrap">
            <div class="example-card">
              <.card_display card={Card.new(:clubs, 11)} />
              <p class="example-label">Draw 5</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:spades, 11)} />
              <p class="example-label">Draw 10</p>
            </div>
            <div class="example-card">
              <.card_display card={Card.new(:diamonds, 11)} />
              <p class="example-label">Draw 5 (canceled one)</p>
            </div>
          </div>
        </div>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">🛡️ Defense Strategy</h4>
        <p>
          Save Red Jacks to cancel Black Jack attacks! They're your best defense against
          devastating draw penalties. Black Jacks are rare and powerful - use them wisely.
        </p>
      </div>
    </div>
    """
  end

  defp render_chapter(:special_queens, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Special Cards: Queens</h2>

      <p class="chapter-text">
        Playing a <strong>Queen</strong> reverses the direction of play! If turns were going clockwise,
        they now go counter-clockwise, and vice versa.
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Reverse Direction</h3>
          <div class="flex justify-center gap-4">
            <.card_display card={Card.new(:hearts, 12)} />
          </div>
          <p class="example-description">Play direction reverses!</p>
        </div>
      </div>

      <h3 class="section-title">Strategic Use</h3>
      <p class="chapter-text">
        Queens are tactical cards that can help you:
      </p>

      <ul class="tutorial-list">
        <li>Skip a player who's about to win by reversing direction</li>
        <li>Get another turn quickly in a 2-player game</li>
        <li>Disrupt the flow of play when it's not in your favor</li>
        <li>Pass the turn back to a player who just drew cards</li>
      </ul>

      <div class="tip-box">
        <h4 class="tip-title">🔄 Tactical Tip</h4>
        <p>
          In a 2-player game, playing a Queen effectively gives you another turn! The direction reverses
          but you're still the next player. Use this to play multiple cards in quick succession.
        </p>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">⚠️ Watch the Direction</h4>
        <p>
          Pay attention to which way play is moving! The game shows an arrow indicator (→ or ←)
          to help you track the current direction.
        </p>
      </div>
    </div>
    """
  end

  defp render_chapter(:special_aces, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Special Cards: Aces</h2>

      <p class="chapter-text">
        Playing an <strong>Ace</strong> lets you nominate (choose) which suit must be played next.
        The next player must match your nominated suit or play another special card.
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Nominate a Suit</h3>
          <div class="flex justify-center gap-4">
            <.card_display card={Card.new(:clubs, 14)} />
          </div>
          <p class="example-description">Choose: ♥ ♦ ♣ or ♠</p>
        </div>
      </div>

      <h3 class="section-title">How Suit Nomination Works</h3>
      <ol class="tutorial-list">
        <li>Play an Ace</li>
        <li>Choose which suit (hearts, diamonds, clubs, or spades) you want</li>
        <li>The next player must play a card of that suit or another special card</li>
        <li>After someone plays, the suit nomination ends</li>
      </ol>

      <h3 class="section-title">Stacking Aces</h3>
      <p class="chapter-text">
        You can play multiple Aces together, but you only nominate the suit <strong>once</strong>.
        The suit you choose applies to all the Aces you played.
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Multiple Aces</h3>
          <div class="flex justify-center gap-4">
            <.card_display card={Card.new(:hearts, 14)} />
            <.card_display card={Card.new(:spades, 14)} />
          </div>
          <p class="example-description">Still only nominate one suit</p>
        </div>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">♠️ Strategic Use</h4>
        <p>
          Use Aces strategically to:
        </p>
        <ul class="tutorial-list">
          <li>Force opponents to play a suit they don't have</li>
          <li>Set up your next play if you have multiple cards of one suit</li>
          <li>Change the suit when you're stuck with one color</li>
        </ul>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">⚠️ Important</h4>
        <p>
          When playing your first Ace, it must match the current suit or rank like any other card.
          Once it's down, then you can nominate any suit you want!
        </p>
      </div>
    </div>
    """
  end

  defp render_chapter(:stacking, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Card Stacking</h2>

      <p class="chapter-text">
        One of Rachel's most powerful mechanics is <strong>stacking</strong> - playing multiple cards
        of the same rank together in a single turn!
      </p>

      <h3 class="section-title">How Stacking Works</h3>
      <p class="chapter-text">
        If you have multiple cards with the same rank (e.g., three 5s or two Kings), you can
        play them all at once. The effects multiply!
      </p>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Stacking Regular Cards</h3>
          <div class="flex justify-center gap-4">
            <.card_display card={Card.new(:hearts, 5)} />
            <.card_display card={Card.new(:clubs, 5)} />
            <.card_display card={Card.new(:diamonds, 5)} />
          </div>
          <p class="example-description">Play three 5s at once!</p>
        </div>
      </div>

      <h3 class="section-title">Stacking Special Cards</h3>
      <p class="chapter-text">
        Special cards become even more powerful when stacked:
      </p>

      <ul class="tutorial-list">
        <li><strong>2s:</strong> Each 2 adds +2 to the draw penalty (three 2s = draw 6 cards)</li>
        <li><strong>7s:</strong> Each 7 skips one more player (two 7s = skip 2 players)</li>
        <li>
          <strong>Black Jacks:</strong> Each adds +5 to the draw penalty (two Black Jacks = draw 10!)
        </li>
        <li>
          <strong>Red Jacks:</strong> Each reduces the attack by -5 cards
        </li>
        <li><strong>Queens:</strong> Each reverses direction (two Queens = back to original direction)</li>
        <li>
          <strong>Aces:</strong> Can stack, but you still only nominate ONE suit for all of them
        </li>
      </ul>

      <div class="card-examples">
        <div class="example-group">
          <h3 class="example-title">Powerful Stack Examples</h3>
          <div class="flex justify-center gap-4 flex-wrap">
            <div class="example-card">
              <div class="flex gap-2">
                <.card_display card={Card.new(:clubs, 2)} />
                <.card_display card={Card.new(:hearts, 2)} />
                <.card_display card={Card.new(:spades, 2)} />
              </div>
              <p class="example-label">Draw 6 cards!</p>
            </div>
            <div class="example-card">
              <div class="flex gap-2">
                <.card_display card={Card.new(:spades, 11)} />
                <.card_display card={Card.new(:clubs, 11)} />
              </div>
              <p class="example-label">Draw 10 cards!</p>
            </div>
          </div>
        </div>
      </div>

      <h3 class="section-title">Stacking Rules</h3>
      <ol class="tutorial-list">
        <li>All stacked cards must have the same rank (all 7s, all Queens, etc.)</li>
        <li>The first card in the stack must be playable (match suit or rank)</li>
        <li>Once valid, you can add as many matching cards as you have</li>
        <li>Effects combine and multiply</li>
      </ol>

      <div class="tip-box">
        <h4 class="tip-title">🎴 Advanced Strategy</h4>
        <p>
          Stacking is key to winning! Save multiple cards of the same rank to create devastating
          combinations. A well-timed stack of attack cards can completely change the game.
        </p>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">⚠️ Important</h4>
        <p>
          You can only stack cards on YOUR turn. You can't add cards to another player's stack,
          but you CAN respond with your own cards if they're attacking you!
        </p>
      </div>
    </div>
    """
  end

  defp render_chapter(:mandatory_play, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Mandatory Play Rule</h2>

      <p class="chapter-text">
        This is one of Rachel's most important rules: <strong>If you have a valid card to play,
        you MUST play it.</strong> You cannot draw cards if you have a playable card in your hand.
      </p>

      <h3 class="section-title">Why This Rule Matters</h3>
      <p class="chapter-text">
        The mandatory play rule prevents players from "fishing" for better cards by drawing when
        they could play. It keeps the game moving and forces strategic decisions about which card
        to play when you have multiple options.
      </p>

      <div class="tip-box">
        <h4 class="tip-title">✅ When You CAN Draw</h4>
        <ul class="tutorial-list">
          <li>You have NO cards that match the current suit or rank</li>
          <li>You're under attack (must draw as penalty)</li>
          <li>You're being skipped (can't play at all)</li>
        </ul>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">❌ When You CANNOT Draw</h4>
        <ul class="tutorial-list">
          <li>You have a card matching the suit</li>
          <li>You have a card matching the rank</li>
          <li>You have a special card that can be played</li>
        </ul>
      </div>

      <h3 class="section-title">Special Cards Always Playable?</h3>
      <p class="chapter-text">
        Special cards (2s, 7s, Jacks, Queens, Aces) still need to match the current suit or rank
        to be played as your <strong>first card</strong>. However:
      </p>

      <ul class="tutorial-list">
        <li>2s can be played to counter other 2s, even if suit doesn't match</li>
        <li>7s can be played to counter other 7s, even if suit doesn't match</li>
        <li>Black Jacks can be played to counter Black Jacks</li>
        <li>Red Jacks can be played to cancel Black Jack attacks</li>
      </ul>

      <h3 class="section-title">Strategic Implications</h3>
      <p class="chapter-text">
        Because you must play when you can, you need to think carefully about:
      </p>

      <ul class="tutorial-list">
        <li><strong>Which card to play</strong> when you have multiple options</li>
        <li><strong>Saving special cards</strong> for when you really need them</li>
        <li><strong>Not holding too many of one suit</strong> - you might be forced to play them</li>
        <li><strong>Planning ahead</strong> for what suits you want to see next</li>
      </ul>

      <div class="tip-box">
        <h4 class="tip-title">🎯 Pro Tip</h4>
        <p>
          Sometimes you'll have to make tough choices! If you have both a regular card and a special card
          that can be played, think about which one helps your strategy more. Save your powerful cards
          for critical moments.
        </p>
      </div>

      <div class="tip-box">
        <h4 class="tip-title">⚠️ The Game Enforces This</h4>
        <p>
          The game interface will prevent you from drawing if you have valid plays. The draw button
          will be disabled until you truly have no playable cards. This keeps the game fair and fast!
        </p>
      </div>
    </div>
    """
  end

  defp render_chapter(:winning, assigns) do
    ~H"""
    <div class="chapter">
      <h2 class="chapter-title">Winning the Game</h2>

      <p class="chapter-text">
        The goal of Rachel is simple: <strong>Be the first player to play all your cards!</strong>
        The moment your hand is empty, you win the game.
      </p>

      <h3 class="section-title">How to Win</h3>
      <ol class="tutorial-list">
        <li>Start with 7 cards (standard game)</li>
        <li>Play your cards strategically throughout the game</li>
        <li>Use special cards to slow down opponents</li>
        <li>Play your last card when you can</li>
        <li>Celebrate your victory! 🎉</li>
      </ol>

      <h3 class="section-title">Last Card Strategy</h3>
      <p class="chapter-text">
        When you're down to your last card, think carefully:
      </p>

      <ul class="tutorial-list">
        <li>
          <strong>Is it a special card?</strong> You might want to play other cards first and save it
        </li>
        <li>
          <strong>Is it a common suit/rank?</strong> Easy to play when the chance comes
        </li>
        <li>
          <strong>Are opponents watching?</strong> They might try to prevent the suit/rank you need
        </li>
      </ul>

      <h3 class="section-title">Getting Close to Winning</h3>
      <p class="chapter-text">
        When you have 2-3 cards left, you're in the danger zone! Opponents will try to:
      </p>

      <ul class="tutorial-list">
        <li><strong>Attack you</strong> with 2s and Black Jacks to make you draw</li>
        <li><strong>Skip you</strong> with 7s to delay your victory</li>
        <li><strong>Change the suit</strong> with Aces to suits you don't have</li>
        <li><strong>Reverse direction</strong> with Queens to skip over you</li>
      </ul>

      <div class="tip-box">
        <h4 class="tip-title">🛡️ Defense Tips</h4>
        <p>When you're close to winning, keep defensive cards if possible:</p>
        <ul class="tutorial-list">
          <li>2s to counter attack cards</li>
          <li>7s to counter skip cards</li>
          <li>Red Jacks to cancel Black Jacks</li>
          <li>Aces to control the suit when it's your turn</li>
        </ul>
      </div>

      <h3 class="section-title">Multiple Winners</h3>
      <p class="chapter-text">
        In rare cases, if you play your last cards as a stack and other effects cause multiple
        players to empty their hands in the same turn, the player who played first wins!
      </p>

      <h3 class="section-title">After Winning</h3>
      <p class="chapter-text">
        When you win:
      </p>

      <ul class="tutorial-list">
        <li>The game announces your victory with celebration animations</li>
        <li>Final scores and statistics are recorded</li>
        <li>You can start a new game or return to the lobby</li>
      </ul>

      <div class="tip-box">
        <h4 class="tip-title">🏆 Master Strategy</h4>
        <p>
          Winning Rachel isn't just about playing fast - it's about timing, defense, and reading
          your opponents. The best players know when to attack, when to defend, and when to race
          for the finish!
        </p>
      </div>

      <div class="tip-box tip-box-success">
        <h4 class="tip-title">🎓 You're Ready!</h4>
        <p>
          Congratulations! You now know all the rules of Rachel. The best way to improve is to play!
          Head to the lobby, start a game, and put your knowledge into practice. Good luck!
        </p>
      </div>
    </div>
    """
  end

  # Helper functions for navigation
  defp get_previous_chapter(current_id) do
    current_order = get_chapter_order(current_id)

    if current_order > 1 do
      Enum.find(@chapters, fn c -> c.order == current_order - 1 end)
    else
      nil
    end
  end

  defp get_next_chapter(current_id) do
    current_order = get_chapter_order(current_id)
    max_order = length(@chapters)

    if current_order < max_order do
      Enum.find(@chapters, fn c -> c.order == current_order + 1 end)
    else
      nil
    end
  end

  defp get_chapter_order(chapter_id) do
    chapter = Enum.find(@chapters, fn c -> c.id == chapter_id end)
    chapter.order
  end

  # Reuse existing card_display component from GameLive
  attr :card, :any, required: true

  defp card_display(assigns) do
    ~H"""
    <div class={[
      "card w-20 h-28 bg-white rounded-lg border-2 flex flex-col items-center justify-center shadow-lg",
      card_color_class(@card)
    ]}>
      <span class="text-3xl font-bold"><%= rank_display(@card) %></span>
      <span class="text-4xl"><%= suit_symbol(@card) %></span>
    </div>
    """
  end

  defp card_color_class(%Card{suit: suit}) when suit in [:hearts, :diamonds],
    do: "border-red-500 text-red-600"

  defp card_color_class(%Card{suit: suit}) when suit in [:clubs, :spades],
    do: "border-black text-black"

  defp rank_display(%Card{rank: rank}) when rank == 11, do: "J"
  defp rank_display(%Card{rank: rank}) when rank == 12, do: "Q"
  defp rank_display(%Card{rank: rank}) when rank == 13, do: "K"
  defp rank_display(%Card{rank: rank}) when rank == 14, do: "A"
  defp rank_display(%Card{rank: rank}), do: to_string(rank)

  defp suit_symbol(%Card{suit: :hearts}), do: "♥"
  defp suit_symbol(%Card{suit: :diamonds}), do: "♦"
  defp suit_symbol(%Card{suit: :clubs}), do: "♣"
  defp suit_symbol(%Card{suit: :spades}), do: "♠"
end

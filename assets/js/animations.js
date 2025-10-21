// Card animation hooks for Rachel card game
// Handles visual animations for card play, draw, and other game actions

export const AnimationHooks = {
  // Hook for animating cards when played
  CardPlayAnimation: {
    mounted() {
      // Listen for card play events from the server
      this.handleEvent("card-played", ({cards}) => {
        if (!cards || cards.length === 0) return;

        // Find all selected cards in the DOM
        const selectedCards = this.el.querySelectorAll('.card.ring-4');

        // Animate each selected card
        selectedCards.forEach((card, index) => {
          // Stagger animations slightly for multiple cards
          setTimeout(() => {
            // Add the playing animation class
            card.classList.add('phx-submit-loading');

            // Remove the card from DOM after animation completes
            setTimeout(() => {
              card.style.opacity = '0';
            }, 500); // Match animation duration from CSS
          }, index * 100); // 100ms stagger between cards
        });
      });
    }
  },

  // Hook for animating cards when drawn
  CardDrawAnimation: {
    mounted() {
      // Track previous hand size to detect new cards
      this.previousHandSize = this.el.querySelectorAll('.card').length;

      // Listen for draw events from the server
      this.handleEvent("cards-drawn", ({count}) => {
        // Wait a brief moment for LiveView to update the DOM
        setTimeout(() => {
          const cards = this.el.querySelectorAll('.card');
          const currentHandSize = cards.length;

          // Find newly added cards (last N cards)
          const newCardsCount = currentHandSize - this.previousHandSize;

          if (newCardsCount > 0) {
            // Get the last N cards
            const newCards = Array.from(cards).slice(-newCardsCount);

            // Animate each new card
            newCards.forEach((card, index) => {
              // Stagger animations slightly
              setTimeout(() => {
                card.classList.add('card-entering');

                // Remove animation class after it completes
                setTimeout(() => {
                  card.classList.remove('card-entering');
                }, 600); // Match animation duration from CSS
              }, index * 100); // 100ms stagger between cards
            });
          }

          // Update hand size for next draw
          this.previousHandSize = currentHandSize;
        }, 100); // Small delay to let LiveView update DOM
      });
    },

    updated() {
      // Update hand size when component updates
      this.previousHandSize = this.el.querySelectorAll('.card').length;
    }
  },

  // Hook for turn transition animations
  TurnTransition: {
    mounted() {
      this.handleEvent("turn-changed", ({isYourTurn}) => {
        const gameBoard = document.querySelector('.game-container');

        if (isYourTurn) {
          // Add subtle glow/highlight when it becomes your turn
          gameBoard?.classList.add('your-turn-glow');

          setTimeout(() => {
            gameBoard?.classList.remove('your-turn-glow');
          }, 1000);
        }
      });
    }
  },

  // Hook for card selection feedback
  CardSelection: {
    mounted() {
      // Add hover and selection effects
      this.el.addEventListener('mouseenter', (e) => {
        if (this.el.classList.contains('cursor-pointer')) {
          this.el.classList.add('card-hover');
        }
      });

      this.el.addEventListener('mouseleave', () => {
        this.el.classList.remove('card-hover');
      });
    }
  },

  // Hook for dealing cards animation on game start
  DealCards: {
    mounted() {
      const cards = this.el.querySelectorAll('.card');

      // Animate cards appearing one by one
      cards.forEach((card, index) => {
        card.style.opacity = '0';
        card.style.transform = 'translateX(-200px) scale(0.5) rotate(-10deg)';

        setTimeout(() => {
          card.style.transition = 'all 0.6s cubic-bezier(0.34, 1.56, 0.64, 1)';
          card.style.opacity = '1';
          card.style.transform = 'translateX(0) scale(1) rotate(0deg)';
        }, index * 50); // Fast stagger for initial deal
      });
    }
  },

  // Hook for attack counter pulse
  AttackCounter: {
    mounted() {
      // The CSS animation is already applied via the "attack-counter" class
      // This hook could be used for additional effects if needed

      this.handleEvent("attack-stacked", ({total}) => {
        // Flash effect when attack is increased
        this.el.classList.add('flash-red');

        setTimeout(() => {
          this.el.classList.remove('flash-red');
        }, 300);
      });
    }
  },

  // Hook for skip counter pulse
  SkipCounter: {
    mounted() {
      // The CSS animation is already applied via the "skip-counter" class
      // This hook could be used for additional effects if needed

      this.handleEvent("skip-stacked", ({total}) => {
        // Flash effect when skip is increased
        this.el.classList.add('flash-yellow');

        setTimeout(() => {
          this.el.classList.remove('flash-yellow');
        }, 300);
      });
    }
  }
};

export default AnimationHooks;

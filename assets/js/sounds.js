// Sound effects manager for Rachel card game
class SoundManager {
  constructor() {
    this.sounds = {};
    this.enabled = localStorage.getItem('soundEnabled') !== 'false';
    this.volume = parseFloat(localStorage.getItem('soundVolume') || '0.5');
    
    // Define sound files (we'll add the actual files later)
    this.soundFiles = {
      cardPlay: '/sounds/card-play.mp3',
      cardDraw: '/sounds/card-draw.mp3',
      cardFlip: '/sounds/card-flip.mp3',
      shuffle: '/sounds/shuffle.mp3',
      skip: '/sounds/skip.mp3',
      reverse: '/sounds/reverse.mp3',
      drawTwo: '/sounds/draw-two.mp3',
      drawFive: '/sounds/draw-five.mp3',
      wildCard: '/sounds/wild-card.mp3',
      yourTurn: '/sounds/your-turn.mp3',
      win: '/sounds/win.mp3',
      lose: '/sounds/lose.mp3',
      error: '/sounds/error.mp3',
      click: '/sounds/click.mp3'
    };
    
    // Preload sounds
    this.preloadSounds();
  }
  
  preloadSounds() {
    Object.entries(this.soundFiles).forEach(([key, path]) => {
      const audio = new Audio(path);
      audio.volume = this.volume;
      audio.preload = 'auto';
      this.sounds[key] = audio;
    });
  }
  
  play(soundName) {
    if (!this.enabled) return;
    
    const sound = this.sounds[soundName];
    if (sound) {
      // Clone and play to allow overlapping sounds
      const audio = sound.cloneNode();
      audio.volume = this.volume;
      audio.play().catch(e => {
        // Silently fail if sound can't play (e.g., file not found)
        console.debug(`Could not play sound ${soundName}:`, e);
      });
    }
  }
  
  setEnabled(enabled) {
    this.enabled = enabled;
    localStorage.setItem('soundEnabled', enabled);
  }
  
  setVolume(volume) {
    this.volume = Math.max(0, Math.min(1, volume));
    localStorage.setItem('soundVolume', this.volume);
    
    // Update volume for all preloaded sounds
    Object.values(this.sounds).forEach(audio => {
      audio.volume = this.volume;
    });
  }
}

// Create singleton instance
const soundManager = new SoundManager();

// Phoenix LiveView Hooks for sound integration
export const SoundHooks = {
  // Hook for playing sounds based on game events
  GameSounds: {
    mounted() {
      // Listen for sound events from the server
      this.handleEvent("play-sound", ({sound}) => {
        soundManager.play(sound);
      });
      
      // Listen for card play events
      this.handleEvent("card-played", ({cards, player}) => {
        if (!cards || cards.length === 0) return;
        
        const card = cards[0];
        // Play different sounds based on card type
        if (card.rank === 7) {
          soundManager.play('skip');
        } else if (card.rank === 12) {
          soundManager.play('reverse');
        } else if (card.rank === 2) {
          soundManager.play('drawTwo');
        } else if (card.rank === 11 && (card.suit === 'spades' || card.suit === 'clubs')) {
          soundManager.play('drawFive');
        } else if (card.rank === 14) {
          soundManager.play('wildCard');
        } else {
          soundManager.play('cardPlay');
        }
      });
      
      // Listen for draw events
      this.handleEvent("cards-drawn", ({count}) => {
        soundManager.play('cardDraw');
      });
      
      // Listen for turn changes
      this.handleEvent("turn-changed", ({isYourTurn}) => {
        if (isYourTurn) {
          soundManager.play('yourTurn');
        }
      });
      
      // Listen for game over
      this.handleEvent("game-over", ({winner, isWinner}) => {
        if (isWinner) {
          soundManager.play('win');
        } else {
          soundManager.play('lose');
        }
      });
    }
  },
  
  // Hook for the victory sound effect
  VictorySound: {
    mounted() {
      soundManager.play('win');
    }
  },
  
  // Hook for sound settings control
  SoundSettings: {
    mounted() {
      // Initialize UI with current settings
      const enabledCheckbox = this.el.querySelector('#sound-enabled');
      const volumeSlider = this.el.querySelector('#sound-volume');
      
      if (enabledCheckbox) {
        enabledCheckbox.checked = soundManager.enabled;
        enabledCheckbox.addEventListener('change', (e) => {
          soundManager.setEnabled(e.target.checked);
        });
      }
      
      if (volumeSlider) {
        volumeSlider.value = soundManager.volume * 100;
        volumeSlider.addEventListener('input', (e) => {
          soundManager.setVolume(e.target.value / 100);
        });
      }
    }
  },
  
  // Hook for UI click sounds
  ClickSound: {
    mounted() {
      this.el.addEventListener('click', () => {
        soundManager.play('click');
      });
    }
  }
};

export default soundManager;
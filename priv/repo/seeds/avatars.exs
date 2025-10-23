# priv/repo/seeds/avatars.exs
alias Rachel.Repo
alias Rachel.Game.Avatar

# Clear existing avatars
Repo.delete_all(Avatar)

avatars = [
  # Faces/Emotions (10)
  %{name: "Smiling Face", category: "faces", character: "😀", display_order: 1},
  %{name: "Cool Sunglasses", category: "faces", character: "😎", display_order: 2},
  %{name: "Thinking Face", category: "faces", character: "🤔", display_order: 3},
  %{name: "Sleeping Face", category: "faces", character: "😴", display_order: 4},
  %{name: "Hugging Face", category: "faces", character: "🤗", display_order: 5},
  %{name: "Star Eyes", category: "faces", character: "🤩", display_order: 6},
  %{name: "Winking Face", category: "faces", character: "😉", display_order: 7},
  %{name: "Laughing", category: "faces", character: "😂", display_order: 8},
  %{name: "Heart Eyes", category: "faces", character: "😍", display_order: 9},
  %{name: "Party Face", category: "faces", character: "🥳", display_order: 10},

  # Animals (10)
  %{name: "Dog", category: "animals", character: "🐶", display_order: 11},
  %{name: "Cat", category: "animals", character: "🐱", display_order: 12},
  %{name: "Panda", category: "animals", character: "🐼", display_order: 13},
  %{name: "Fox", category: "animals", character: "🦊", display_order: 14},
  %{name: "Lion", category: "animals", character: "🦁", display_order: 15},
  %{name: "Tiger", category: "animals", character: "🐯", display_order: 16},
  %{name: "Unicorn", category: "animals", character: "🦄", display_order: 17},
  %{name: "Penguin", category: "animals", character: "🐧", display_order: 18},
  %{name: "Koala", category: "animals", character: "🐨", display_order: 19},
  %{name: "Frog", category: "animals", character: "🐸", display_order: 20},

  # Objects (10)
  %{name: "Game Controller", category: "objects", character: "🎮", display_order: 21},
  %{name: "Dart", category: "objects", character: "🎯", display_order: 22},
  %{name: "Artist Palette", category: "objects", character: "🎨", display_order: 23},
  %{name: "Rocket", category: "objects", character: "🚀", display_order: 24},
  %{name: "Lightning", category: "objects", character: "⚡", display_order: 25},
  %{name: "Trophy", category: "objects", character: "🏆", display_order: 26},
  %{name: "Crown", category: "objects", character: "👑", display_order: 27},
  %{name: "Crystal Ball", category: "objects", character: "🔮", display_order: 28},
  %{name: "Microphone", category: "objects", character: "🎤", display_order: 29},
  %{name: "Camera", category: "objects", character: "📷", display_order: 30},

  # Cards/Gaming (8)
  %{name: "Playing Card", category: "cards", character: "🃏", display_order: 31},
  %{name: "Spade", category: "cards", character: "♠️", display_order: 32},
  %{name: "Heart", category: "cards", character: "♥️", display_order: 33},
  %{name: "Diamond", category: "cards", character: "♦️", display_order: 34},
  %{name: "Club", category: "cards", character: "♣️", display_order: 35},
  %{name: "Dice", category: "cards", character: "🎲", display_order: 36},
  %{name: "Slot Machine", category: "cards", character: "🎰", display_order: 37},
  %{name: "Chess Pawn", category: "cards", character: "♟️", display_order: 38},

  # Food (8)
  %{name: "Pizza", category: "food", character: "🍕", display_order: 39},
  %{name: "Burger", category: "food", character: "🍔", display_order: 40},
  %{name: "Taco", category: "food", character: "🌮", display_order: 41},
  %{name: "Sushi", category: "food", character: "🍣", display_order: 42},
  %{name: "Cake", category: "food", character: "🎂", display_order: 43},
  %{name: "Ice Cream", category: "food", character: "🍦", display_order: 44},
  %{name: "Donut", category: "food", character: "🍩", display_order: 45},
  %{name: "Coffee", category: "food", character: "☕", display_order: 46},

  # Nature (8)
  %{name: "Star", category: "nature", character: "⭐", display_order: 47},
  %{name: "Glowing Star", category: "nature", character: "🌟", display_order: 48},
  %{name: "Rainbow", category: "nature", character: "🌈", display_order: 49},
  %{name: "Fire", category: "nature", character: "🔥", display_order: 50},
  %{name: "Diamond Gem", category: "nature", character: "💎", display_order: 51},
  %{name: "Moon", category: "nature", character: "🌙", display_order: 52},
  %{name: "Sun", category: "nature", character: "☀️", display_order: 53},
  %{name: "Sparkles", category: "nature", character: "✨", display_order: 54}
]

Enum.each(avatars, fn avatar_attrs ->
  %Avatar{}
  |> Avatar.changeset(avatar_attrs)
  |> Repo.insert!()
end)

IO.puts("✅ Seeded #{length(avatars)} avatars")

###
A random AI for the Dots AI environment.
Copyright (c) 2014 Anthony Bau.
MIT License.
###

kbd = require 'kbd'

# Read in the dimensions of the board
[WIDTH, HEIGHT] = kbd.getLineSync().trim().split ' '

DIRS = 'nsew'.split ''

# ## genMove
# Get a fully random move string.
genMove = ->
  [Math.floor(Math.random() * WIDTH), # Random x between 0 and WIDTH
  Math.floor(Math.random() * HEIGHT), # Random y between 0 and WIDTH
  DIRS[Math.floor(Math.random() * 4)] # Random direction
  ].join ' '

# We need to keep a history of the moves
# so that we don't make a redundant move and thus
# forfeit the game
history = {}

# Conveneince dictionaries for inverting
# and moving along cardinal directions.
dirs = {
  'n': {x: 0, y: -1}
  's': {x: 0, y: 1}
  'e': {x: 1, y: 0}
  'w': {x: -1, y: 0}
}

inverse = {
  'n': 's'
  's': 'n'
  'e': 'w'
  'w': 'e'
}

# ## The game loop
while true
  moves = kbd.getLineSync()

  # Go through all the moves and
  # record that they happened so that
  # we don't do them too
  for str in moves.split '|'
    if str.length > 1
      # Mark the move as done.
      history[str.trim()] = true

      # Mark the other name for this move
      # (the adjacent square and opposite direction)
      # as also done>
      [x, y, d] = str.trim().split ' '
      dir = dirs[d]
      history[[(+x + dir.x), (+y + dir.y), inverse[d]].join ' '] = true

  # Now generate fully-random moves until we come upon
  # a legal one.
  move = genMove()
  while move of history
    move = genMove()

  # Add this move and its identical twin to
  # our move history so we don't do it again.
  str = move
  history[str.trim()] = true # The move
  [x, y, d] = str.trim().split ' '
  dir = dirs[d]
  history[[(+x + dir.x), (+y + dir.y), inverse[d]].join ' '] = true # The twin

  # Output the move we found.
  console.log move

  if Math.random() > 0.9
    throw new Error 'I am awful'

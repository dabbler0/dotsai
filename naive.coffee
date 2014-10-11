###
A naive AI for the Dots AI environment.
Copyright (c) 2014 Anthony Bau.
MIT License.
###
kbd = require 'kbd'

# Read in the dimensions of the board.
[WIDTH, HEIGHT] = (Number(d) for d in kbd.getLineSync().trim().split ' ')

# Convenience constant equal to `['n', 's', 'e', 'w']`
DIRS = 'nsew'.split ''

# ## rand
# A simple convenience function for generating either
# a random natural number less than `x` or choosing a random
# element of the array `x`.
rand = (x) ->
  if (typeof x is 'number') or x instanceof Number
    return Math.floor Math.random() * x
  if x instanceof Array
    return x[Math.floor Math.random() * x.length]

# ## Square
# An object representing the space between
# four dots on the board, with some convenience methods.
#
# Edges and completeness are numbers representing the player
# who filled the square or placed the edge. No player can have number -1, which
# represents no players.
class Square
  constructor: ->
    @n = @s = @e = @w = -1
    @complete = -1

  testComplete: -> @n >= 0 and @s >= 0 and @e >= 0 and @w >= 0

  # If a square has three sides filled, `toComplete` gives
  # the remaining side; otherwise null.
  toComplete: ->
    remnant = DIRS.filter((d) => @[d] < 0)
    if remnant.length is 1 then return remnant[0]
    else null

# Convenience dictionaries for inverting directions
# or moving in them
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

# ## Move
# A convenience wrapper around three values: x and y
# (representing the coordinate of the desired square), and direction.
class Move
  constructor: (@x, @y, @d) ->

  toString: -> [@x, @y, @d].join ' '

# ## Move.fromString
# Simple parser that parse `x y d` into `Move(x, y, d)`
Move.fromString = (str) ->
  [x, y, d] = str.trim().split ' '
  x = Number x; y = Number y
  return new Move x, y, d

# ## Board
# Class representing the game state, with methods for taking turns.
#
# Edges are represented redundantly as sides of squares.
class Board
  constructor: (@w, @h) ->
    @squares = ((new Square() for [0...@h]) for [0...@w]) # Array of all the `Square`s on the board
    @scores = [0, 0] # Player scores
    @turn = 0 # Whose turn; an index in the @scores array
    @done = false # Hacky field to prevent more moves after the game is over

  place: (move) ->
    # Extract x, y, and d from the move
    {x, y, d} = move

    # If the move is illegal, say so
    if @squares[x][y][d] >= 0
      throw new Error "Player #{@turn} forfeits; illegal move at #{x} #{y} #{d}"

    # Otherwise, place the edge, recording
    # the player who placed it
    @squares[x][y][d] = @turn

    # We also need to place the edge on the other side
    # of the square next to us (redundant storage).
    dir = dirs[d]
    @squares[x + dir.x]?[y + dir.y]?[inverse[d]] = @turn

    # Now see if we completed any squares.
    complete = false

    # We can only have completed one of two squares;
    # the one the player chose or the one on the opposite
    # side of the edge they placed. Test both.
    #
    # If we found that a square was completed, record this, increase
    # the current player's score, and set the `complete flag to
    # give them an extra turn
    if @squares[x][y].testComplete()
      @scores[@turn]++
      @squares[x][y].complete = @turn
      complete = true

    if @squares[x + dir.x]?[y + dir.y]?.testComplete?() ? false
      @scores[@turn]++
      @squares[x + dir.x][y + dir.y].complete = @turn
      complete = true

    # Test to see if we are done
    @done = true
    for col, x in @squares
      for square, y in col
        if square.complete < 0
          @done = false
          break
      unless @done
        break

    # Give the player an extra turn if the `complete
    # flag is set; otherwise advance the turn index.
    unless complete
      @turn = (@turn + 1) %% @scores.length

  # `eachSquare` is a convenience iterator
  # over all squares. Passes their coordinates, along with the
  # square object itself, to the callback `fn`.
  eachSquare: (fn) ->
    for col, x in @squares
      for square, y in col
        fn square, {x: x, y: y}

  # `getRandomMove` gets a random legal `Move` object for
  # this board. Just keeps generating random moves until
  # one of them is legal.
  getRandomMove: ->
    [x, y, d] = [rand(@w), rand(@h), rand(DIRS)]
    until @squares[x][y][d] < 0
      [x, y, d] = [rand(@w), rand(@h), rand(DIRS)]
    return new Move x, y, d

# Instantiate our `Board` model to keep track
# of things
board = new Board WIDTH, HEIGHT

# ## Game loop
while true
  # Read in the information the contest environment gives us and
  # apply it to the `Board` model.
  moves = (Move.fromString(str) for str in kbd.getLineSync().trim().split('|') when str.length > 1)
  for move in moves
    board.place move

  # Now decide on our move.
  madeMove = false

  # First see if there is a three-side square
  # we can fill; we will chose the first one
  # we see, if there is any.
  board.eachSquare (square, coord) ->
    unless madeMove
      remnant = square.toComplete()
      if remnant?
        move = new Move coord.x, coord.y, remnant
        madeMove = true

  # Otherwise, we will choose a random legal
  # move.
  unless madeMove
    move = board.getRandomMove()

  # Output the move on which we've decided
  console.log move.toString()

  # Update our `Board` model to reflect
  # our own move as well.
  board.place move

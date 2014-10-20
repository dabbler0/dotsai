###
A naive AI for the Dots AI environment.
Copyright (c) 2014 Anthony Bau.
MIT License.
###
kbd = require 'kbd'
colors = require 'colors'
fs = require 'fs'

MAX_NUM_EVALS = 5
MAX_EXAMINATIONS = 40
PLAYER_NUM = 0

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

  toCompleteNot: (exclude) ->
    remnant = DIRS.filter((d) => (@[d] < 0) and (d isnt exclude))
    if remnant.length is 1 then return remnant[0]
    else null

  remaining: -> DIRS.filter((d) => @[d] < 0)

  remnant: -> DIRS.filter((d) => @[d] < 0).length
  equal: (other) ->
    (@n < 0) is (other.n < 0) and
    (@s < 0) is (other.s < 0) and
    (@e < 0) is (other.e < 0) and
    (@w < 0) is (other.w < 0)

  clone: ->
    clone = new Square()
    clone[p] = @[p] for p in ['n', 's', 'e', 'w', 'complete']
    return clone

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
    @remainingMoves = @w * @h * 2 + @w + @h
    @threeSquares = []

  place: (move) ->
    unless move? and move.x? and move.y? and move.d?
      console.warn move
    # Extract x, y, and d from the move
    {x, y, d} = move

    # If the move is illegal, say so
    if @squares[x][y][d] >= 0
      throw new Error "Player #{@turn} forfeits; illegal move at #{x} #{y} #{d}"

    @remainingMoves--

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
    else if @squares[x][y].toComplete()?
      @threeSquares.push {x: x, y: y}

    if @squares[x + dir.x]?[y + dir.y]?.testComplete?() ? false
      @scores[@turn]++
      @squares[x + dir.x][y + dir.y].complete = @turn
      complete = true
    else if @squares[x + dir.x]?[y + dir.y]?.toComplete()? ? false
      @threeSquares.push {x: x + dir.x, y: y + dir.y}

    @threeSquares = @threeSquares.filter (coord) => @squares[coord.x][coord.y].complete < 0

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
    shouldBreak = false
    for col, x in @squares
      for square, y in col
        shouldCont = fn square, {x: x, y: y}
        unless shouldCont then break
      unless shouldCont then break

  computeDamage: (originalCoord) ->
    damage = 1; visited = {}
    for dir in @squares[originalCoord.x][originalCoord.y].remaining()
      coord = {x: originalCoord.x + dirs[dir].x, y: originalCoord.y + dirs[dir].y}
      square = @squares[coord.x]?[coord.y]

      while square? and ((coord.x + ',' + coord.y) not of visited) and (dir = square.toCompleteNot inverse[dir])?
        damage += 1
        visited[(coord.x + ',' + coord.y)] = true
        coord.x += dirs[dir].x; coord.y += dirs[dir].y
        square = @squares[coord.x]?[coord.y]

    return damage

  clone: ->
    clone = new Board @w, @h
    @eachSquare (square, coord) =>
      clone.squares[coord.x][coord.y] = square.clone()
      return true

    clone.remainingMoves = @remainingMoves
    clone.turn = @turn
    clone.scores[0] = @scores[0]
    clone.scores[1] = @scores[1]
    clone.threeSquares = (coord for coord in @threeSquares)

    return clone

  getStepWithMove: (move) ->
    clone = @clone()
    clone.place move
    return clone

  possibleMoves: ->
    moves = []
    @eachSquare (square, coord) =>
      unless square.remnant() is 2
        for dir in DIRS
          m = dirs[dir]
          if square[dir] < 0 and @squares[coord.x + m.x]?[coord.y + m.y]?.remnant?() isnt 2
            moves.push new Move coord.x, coord.y, dir
      return true
    moves = moves.sort((a, b) -> Math.random() - 0.5)[0...MAX_EXAMINATIONS]
    return moves

  getNextStates: ->
    states = []

    for move in @possibleMoves()
      states.push @getStepWithMove move

    return states

  evaluate: (player, debug = false) ->
    board = @clone()

    until board.remainingMoves is 0
      board.place board.getRandomMove()

    return if (board.scores[player]) > (@w * @h / 2) then 1 else 0

  getBestTwoSquare: ->
    # Third, reduce damage as much as possible.
    bestDamage = Infinity; bestMove = null
    @eachSquare (square, coord) =>
      if square.remnant() is 2 and (damage = @computeDamage(coord)) < bestDamage
        bestMove = new Move coord.x, coord.y, square.remaining()[0]
        bestDamage = damage
      return true
    return bestMove

  # `getRandomMove` gets a random legal `Move` object for
  # this board. Just keeps generating random moves until
  # one of them is legal.
  getRandomMove: ->
    # First, check to see if there are any uncompleted three-squares
    madeMove = false; move = null

    if @threeSquares.length > 0
      c = @threeSquares.shift()
      return new Move c.x, c.y, @squares[c.x][c.y].toComplete()

    # Second, check to see if there are any places we can put something
    # without making a three-square.
    moves = []
    @eachSquare (square, coord) =>
      unless square.remnant() is 2
        for dir in DIRS
          m = dirs[dir]
          if square[dir] < 0 and @squares[coord.x + m.x]?[coord.y + m.y]?.remnant?() isnt 2
            moves.push new Move coord.x, coord.y, dir
      return true

    if moves.length > 0
      return rand moves

    return @getBestTwoSquare()

  equal: (other) ->
    result = true
    result and= @w is other.w and @h is other.h

    @eachSquare (square, coord) =>
      return result and= square.equal other.squares[coord.x][coord.y]

    return result

  impossibleMoves: ->
    moves = []
    @eachSquare (square, coord) =>
      if square.remnant() is 2
        for dir in DIRS
          if square[dir] < 0
            moves.push new Move coord.x, coord.y, dir
      return true
    return moves

  getMetaRandomMove: (depth, player = PLAYER_NUM) ->
    if @possibleMoves().length is 0 and @evaluate(player) is 0
      return @getBestTwoSquare()
    else
      return @getRandomMove()

  getSearchMove: (depth) ->
    finalStates = []
    states = []

    possibleMoves = @possibleMoves()
    if possibleMoves.length is 0
      return @getRandomMove()

    for move in possibleMoves
      states.push {move: move, board: @getStepWithMove(move)}

    bestEval = 0; bestMove = null
    for state in states
      evaluation = 0
      for [1..Math.ceil(MAX_NUM_EVALS / Math.ceil(possibleMoves.length / 10))]
        evaluation += state.board.evaluate PLAYER_NUM
      if evaluation is Math.ceil(MAX_NUM_EVALS / Math.ceil(possibleMoves.length / 10))
        return state.move
      if evaluation > bestEval
        bestMove = state.move
        bestEval = evaluation

    if bestMove?
      return bestMove
    else
      return @getMetaRandomMove()

  render: ->
    strs = ('' for [0..2 * @h])
    # Go through the squares, and print characters
    # for only the northern and western edges of each of them (to avoid
    # redundant printing).
    for col, x in @squares
      for square, y in col
        # Northern edge, and northwestern corner "dot"
        strs[2 * y] += '*' + (if square.n >= 0 then horizChars[square.n] else ' ')

        # Western edge, and middle fill symbol, if the square has been completed
        strs[2 * y + 1] += (if square.w >= 0 then vertChars[square.w] else ' ') +
            (if square.complete >= 0 then fillChars[square.complete] else ' ')

        # Also add the eastern edge and northestern corner "dot" if we are the rightmost square,
        # since nobody else is going to print that edge for us.
        if y is col.length - 1
          strs[2 * y + 2] += '*' + (if square.s >= 0 then horizChars[square.s] else ' ')

    # Also add the southern edge of all the southernmost squares,
    # since those are not covered by any other squares.
    for square, y in @squares[@squares.length - 1]
      strs[2 * y] += '*' # Also add the southwestern corner
      strs[2 * y + 1] += (if square.e >= 0 then vertChars[square.e] else ' ')

    # One dot is still left out -- the southeastern corner of the southeasternmost square. Add it here.
    return strs.join('\n') + '*' + "\n(It is turn #{@turn})"

# Convenience color arrays, used above in `render`.
horizChars = ['-'.red, '-'.blue]
vertChars = ['|'.red, '|'.blue]
fillChars = ['#'.red, '#'.blue]

gameBoard = new Board WIDTH, HEIGHT

decidedPlayer = false

while true
  # Read in the information the contest environment gives us and
  # apply it to the `Board` model.
  moves = (Move.fromString(str) for str in kbd.getLineSync().trim().split('|') when str.length > 1)

  unless decidedPlayer
    if moves.length is 0 then PLAYER_NUM = 0
    else PLAYER_NUM = 1
    decidedPlayer = true

  for move in moves
    gameBoard.place move

  if gameBoard.possibleMoves().length is 0
    console.log (move = gameBoard.getMetaRandomMove()).toString()
  else
    console.log (move = gameBoard.getSearchMove()).toString()

  gameBoard.place move

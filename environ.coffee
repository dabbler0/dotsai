###
The Dots contest environment.
Copyright (c) 2014 Anthony Bau.
MIT License.
###
colors = require 'colors'
child_process = require 'child_process'
readline = require 'readline'

# Process command line arguments:
# `-r` or `--rate` for frames-per-second frame rate
# `-h` or `--height` for board height (in squares, not dots)
# `-w` or `--width` for board width (in squares, not dots)
RATE = 500
WIDTH = 10
HEIGHT = 10

for arg, i in process.argv
  if arg in ['--rate', '-r'] and i < process.argv.length - 1
    RATE = 1000 / (Number process.argv[i + 1])
  if arg in ['--width', '-w']
    WIDTH = Number process.argv[i + 1]
  if arg in ['--height', '-h']
    HEIGHT = Number process.argv[i + 1]

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

# ## Player
# A wrapper on a child process with methods for feeding and reading.
class Player
  # Upon construction we must feed the child the dimensions
  # of the board
  constructor: (@script) ->
    if @script is 'HUMAN'
      @human = true
      @iface = readline.createInterface {
        input: process.stdin
        output: process.stdout
      }
    else
      @human = false
      @process = child_process.exec @script
      @process.stdin.write [WIDTH, HEIGHT].join(' ') + '\n'
      @process.stderr.pipe process.stderr
      @process.on 'exit', (code, string) =>
        unless @killed
          throw new Error "Player foreits with exit code #{code}"
      @killed = false

  kill: ->
    unless @human
      @killed = true
      @process.kill()

  # `feed` takes an array of moves (the moves that this player has not performed
  # and have been performed since this player has last moved) and an async callback.
  #
  # We feed moves to the players in the format: `x1 y1 d1|x2 y2 d2|x3 y3 d3` etc.
  # It is possible to feed players an empty string (ended with a newline) if they
  # are the starting player or are moving twice in a row.
  feed: (moves, cb) ->
    if @human
      @iface.question '>', (data) ->
        cb Move.fromString data

    else
      @process.stdin.write (move.toString() for move in moves).join('|') + '\n'

      str = ''
      @process.stdout.once 'data', fn = (data) ->
        str += data.toString()
        if str[str.length - 1] is '\n'
          cb Move.fromString str
        else
          @process.stdout.once 'data', fn

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

  # `render` serializes the board as characters
  # to display on a Linux tty.
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
    return strs.join('\n') + '*'

# Convenience color arrays, used above in `render`.
horizChars = ['-'.red, '-'.blue]
vertChars = ['|'.red, '|'.blue]
fillChars = ['#'.red, '#'.blue]

# ## playGame
# Takes `a` and `b`, shell commands (like `./a.out`, `java MyClass`, or `coffee naive.coffee`), and
# a `Board` instance. Runs a game at `FRAME_RATE`.
playGame = (a, b, board) ->
  # Set up the player shell wrappers
  players = [new Player(a), new Player b]

  # We need a record of all the moves that occurred
  # since the non-playing player moved, so we can
  # feed it to them all at once. Keep this record,
  # along with a record of whose turn it was last
  # so we can detect turn changes.
  lastMoves = []; lastTurn = 0

  # Set up a js "animation" for the advancing game
  (doMove = ->
    # Feed the `lastMove` history unless this player has just gone,
    # in which case feed them nothing, since they already
    # know everything
    fodder = (if board.turn is lastTurn then [] else lastMoves)

    # Ask the player for a move
    players[board.turn].feed fodder, (move) ->
      # If the turn has just switched, clear the `lastMove` history
      if lastTurn isnt board.turn
        lastTurn = board.turn; lastMoves = []

      # Perform the move the player has given us
      board.place move

      # Add the move to the history, kept to feed
      # to the opposing player when it is their turn
      lastMoves.push move

      # Print the current rendered board to the tty.
      console.log '\u001B[2J' + board.render()
      console.log ('RED ' + board.scores[0]).red + '\t' + ('BLUE ' + board.scores[1]).blue
      #console.log '\u001B[0;0f'

      # If the game is over (i.e. the board is full),
      # gracefully kill the players and exit.
      if board.done
        player.kill() for player in players

      # Otherwise, advance the animation tick.
      else
        setTimeout doMove, RATE
  )()

playGame process.argv[2], process.argv[3], new Board WIDTH, HEIGHT

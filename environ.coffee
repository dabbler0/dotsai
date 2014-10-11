colors = require 'colors'
child_process = require 'child_process'

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

class Square
  constructor: ->
    @n = @s = @e = @w = -1
    @complete = -1

  testComplete: -> @n >= 0 and @s >= 0 and @e >= 0 and @w >= 0

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

class Move
  constructor: (@x, @y, @d) ->

  toString: -> [@x, @y, @d].join ' '

Move.fromString = (str) ->
  [x, y, d] = str.trim().split ' '
  x = Number x; y = Number y
  return new Move x, y, d

class Player
  constructor: (@script) ->
    @process = child_process.exec @script
    @process.stdin.write [WIDTH, HEIGHT].join(' ') + '\n'
    @process.on 'exit', (code, string) =>
      unless @killed
        throw new Error "Player foreits with exit code #{code}"
    @killed = false

  kill: ->
    @killed = true
    @process.kill()

  feed: (moves, cb) ->
    @process.stdin.write (move.toString() for move in moves).join('|') + '\n'

    str = ''
    @process.stdout.once 'data', fn = (data) ->
      str += data.toString()
      if str[str.length - 1] is '\n'
        cb Move.fromString str
      else
        @process.stdout.once 'data', fn

class Board
  constructor: (@w, @h) ->
    @squares = ((new Square() for [0...@h]) for [0...@w])
    @scores = [0, 0]
    @turn = 0
    @done = false

  place: (move) ->
    {x, y, d} = move
    if @squares[x][y][d] >= 0
      throw new Error "Player forfeits; illegal move at #{x} #{y} #{d}"

    @squares[x][y][d] = @turn
    dir = dirs[d]
    @squares[x + dir.x]?[y + dir.y]?[inverse[d]] = @turn

    complete = false

    if @squares[x][y].testComplete()
      @scores[@turn]++
      @squares[x][y].complete = @turn
      complete = true
    if @squares[x + dir.x]?[y + dir.y]?.testComplete?() ? false
      @scores[@turn]++
      @squares[x + dir.x][y + dir.y].complete = @turn
      complete = true

    @done = true
    for col, x in @squares
      for square, y in col
        if square.complete < 0
          @done = false
          break
      unless @done
        break

    unless complete
      @turn = (@turn + 1) %% @scores.length

  render: ->
    strs = ('' for [0..2 * @h])
    for col, x in @squares
      for square, y in col
        strs[2 * y] += '*' + (if square.n >= 0 then horizChars[square.n] else ' ')
        strs[2 * y + 1] += (if square.w >= 0 then vertChars[square.w] else ' ') +
            (if square.complete >= 0 then fillChars[square.complete] else ' ')

        if y is col.length - 1
          strs[2 * y + 2] += '*' + (if square.s >= 0 then horizChars[square.s] else ' ')

    for square, y in @squares[@squares.length - 1]
      strs[2 * y] += '*'
      strs[2 * y + 1] += (if square.e >= 0 then vertChars[square.e] else ' ')

    return strs.join('\n') + '*'

horizChars = ['-'.red, '-'.blue]
vertChars = ['|'.red, '|'.blue]
fillChars = ['#'.red, '#'.blue]

playGame = (a, b, board) ->
  players = [new Player(a), new Player b]
  index = 0
  lastMoves = []
  lastTurn = 0
  (doMove = ->
    fodder = (if board.turn is lastTurn then [] else lastMoves)
    players[board.turn].feed fodder, (move) ->
      if lastTurn isnt board.turn
        lastTurn = board.turn; lastMoves = []
      board.place move
      lastMoves.push move
      console.log '\u001B[2J' + board.render()
      console.log ('RED ' + board.scores[0]).red + '\t' + ('BLUE ' + board.scores[1]).blue
      if board.done
        player.kill() for player in players
      else
        setTimeout doMove, RATE
  )()

playGame 'coffee naive.coffee', 'coffee random.coffee', new Board WIDTH, HEIGHT

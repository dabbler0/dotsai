kbd = require 'kbd'

[WIDTH, HEIGHT] = (Number(d) for d in kbd.getLineSync().trim().split ' ')
DIRS = 'nsew'.split ''

rand = (x) ->
  if (typeof x is 'number') or x instanceof Number
    return Math.floor Math.random() * x
  if x instanceof Array
    return x[Math.floor Math.random() * x.length]

class Square
  constructor: ->
    @n = @s = @e = @w = -1
    @complete = -1

  testComplete: -> @n >= 0 and @s >= 0 and @e >= 0 and @w >= 0

  toComplete: ->
    remnant = DIRS.filter((k) => @[k] < 0)
    if remnant.length is 1
      return remnant[0]
    else
      return null

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

  eachSquare: (fn) ->
    for col, x in @squares
      for square, y in col
        fn square, {x: x, y: y}

  getRandomMove: ->
    [x, y, d] = [rand(@w), rand(@h), rand(DIRS)]
    until @squares[x][y][d] < 0
      [x, y, d] = [rand(@w), rand(@h), rand(DIRS)]
    return new Move x, y, d

board = new Board WIDTH, HEIGHT

while true
  moves = (Move.fromString(str) for str in kbd.getLineSync().trim().split('|') when str.length > 1)
  for move in moves
    board.place move

  madeMove = false

  board.eachSquare (square, coord) ->
    unless madeMove
      remnant = square.toComplete()
      if remnant?
        move = new Move coord.x, coord.y, remnant
        madeMove = true

  unless madeMove
    move = board.getRandomMove()

  console.log move.toString()
  board.place move

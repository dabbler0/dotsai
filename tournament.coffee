environ = require './environ'
fs = require 'fs'

scripts = process.argv[2..]
scores = (0 for _ in scripts)
games = 0
timesPlayed = (0 for _ in scripts)

format = (a, b) ->
  topStr = ''
  bottomStr = ''
  for el, i in a
    el = el.toString()
    ol = b[i].toString()

    if el.length > ol.length
      topStr += el + '\t'
      bottomStr += ol + (' ' for [el.length..ol.length]).join('') + '\t'
    else
      bottomStr += ol + (' ' for [ol.length..el.length]).join('') + '\t'
      topStr += el + '\t'

  return topStr + '\n' + bottomStr

queue = []

for red, i in scripts
  for blue, j in scripts when red isnt blue
    queue.push [i, j]

playGame = ->
  [i, j] = queue.pop()
  red = scripts[i]
  blue = scripts[j]

  console.log 'Playing ', red, 'vs', blue
  environ.play red, blue, (board = new environ.Board(6, 6)), (results) ->
    console.log 'done'
    console.log results
    fs.appendFileSync 'history.txt', '\n' + JSON.stringify {
      players: [red, blue]
      scores: [results[0], results[1]]
      moves: board.moves.join '|'
    }
    if queue.length > 0
      playGame()
playGame()

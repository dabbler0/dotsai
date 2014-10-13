environ = require './environ'

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

playGame = ->
  a = scripts[aIndex = Math.floor Math.random() * scripts.length]
  b = scripts[bIndex = Math.floor Math.random() * scripts.length]
  environ.play a, b, new environ.Board(10, 10), (results) ->
    games += 1
    timesPlayed[aIndex] += 1
    timesPlayed[bIndex] += 1
    scores[aIndex] += results[0]
    scores[bIndex] += results[1]

    console.log ''
    console.log a + ' VERSUS ' + b
    console.log '===================='
    console.log results.join '/'
    console.log ''
    console.log 'TOTAL SCORES (' + games + ' GAMES)'
    console.log '===================='

    console.log format(scripts, ((n / timesPlayed[i]).toPrecision(4) + ' (' + timesPlayed[i] + ')' for n, i in scores))
    playGame()
playGame()

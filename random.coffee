kbd = require 'kbd'
[WIDTH, HEIGHT] = kbd.getLineSync().trim().split ' '

genMove = -> [Math.floor(Math.random() * WIDTH), Math.floor(Math.random() * HEIGHT), ['n', 's', 'e', 'w'][Math.floor(Math.random() * 4)]].join ' '
history = {}
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

while true
  moves = kbd.getLineSync()
  for str in moves.split '|'
    if str.length > 1
      [x, y, d] = str.trim().split ' '
      dir = dirs[d]
      history[str.trim()] = true
      history[[(+x + dir.x), (+y + dir.y), inverse[d]].join ' '] = true
  move = genMove()
  while move of history
    move = genMove()

  str = move
  [x, y, d] = str.trim().split ' '
  dir = dirs[d]
  history[str.trim()] = true
  history[[(+x + dir.x), (+y + dir.y), inverse[d]].join ' '] = true

  console.log move

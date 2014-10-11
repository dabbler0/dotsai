DOTS AI
=======

Running the Contest Environment
-------------------------------
You will need [nodejs](nodejs.org). Then install coffeescript:
```
npm install -g coffee-script
```
You may need `sudo`. Install the package itself. In the dotsai root directory:
```
npm install
```
Then, to run:
```
coffee environ.coffee 'java ContestantOne' './contestant_two.out' [-r FRAMES_PER_SECOND] [-w BOARD_WIDTH] [-h BOARD_HEIGHT]
```
Where `java ContestantOne` and `./contestant_two.out` are the actuall shell commands for the AIs you want to compete against each other. A working example:
```
coffee environ.coffee 'coffee naive.coffee' 'coffee random.coffee' -r 5
```
The default board size is 10x10, so this will run a 10x10 game between `naive.coffee` and `random.coffee` at 5 moves per second (`naive.coffee` usually wins this). The default frame rate is one move per second.

Making a Contestant
-------------------
See `naive.coffee` for an example. You will recieve first a single line with the dimensions of the board, first width and then height:
```
5 10
```
Then, when it is your turn, you will recieve a line containing all the moves that have occurred since your last turn. A move is of the form `x y direction`, specifying a square and then an edge of that square. For instance, if the opposing player had made three moves since your last turn, one on the east edge of the square at `(1, 1)`, one on the north edge of the square at `(2, 1)`, and one of the south edge of the square at `(3, 2)`:
```
1 1 e|2 1 n|3 2 s
```
You must output exactly one line after this containing a single move. For instance,
```
3 2 e
```
Your process will be killed with `SIGTERM` when the contest is over.

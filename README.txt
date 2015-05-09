A teeny portion of a game that my kids like.
output: colored ascii
code: meh


compile it:
# osx:
go build mix.go
# assuming you already: brew install go --with-cc-common
# then: brew reinstall go --with-cc-common
# windows:
GOOS=windows GOARCH=386 go build -o mix.exe mix.go

run it: ./mix # alernatively ./mix.rb
then press <enter> (or <return>) when it lands on a "green"
the sooner the better, but if you fail to get a 'green'
then suffer for your lack of timing...

:-)

Initially we played like that: aiming to get the most points
(100% for landing on green within the first few rounds)

Then, my son started trying to see who could click the fastest
Playing for the fastest "time" was a lot more fun

And thanks to my son's feedback, I made our new alternation a more natural fit,
I adjusted the code to start on Green

...But, of course, having green up-against the left edge of the screen wasn't good
that made the regular game too easy.

So I made the game loop skip the first few colors, such that the game starts on "green"
..in the middle of the screen
...and only for a few milliseconds

Now having almost worn-out my keyboard
We've come-up with an even better game --almost as fun and less likely to break my keyboard

Rules:
  1) you must land on green or you lose
  2) you must get at least 500ms or you lose
  3) the winner is the one with the lowest time

I started off with 560ms
My son got 503ms
then (after many attempts) I secured my victory (so far) with: 500.0629ms*

(Note: Yes, we're talking milliseconds ...not seconds)


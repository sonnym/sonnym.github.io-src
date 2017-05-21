---
layout: post
title: Revisiting the Game of Life in Elm
date: 2017-05-22
tags:
  - elm
  - game of life
---

## Reflection

Over three years ago, I wrote an
[article]({% link _posts/2014-05-05-writing-game-of-life-in-elm.markdown %})
exploring how to write Conway's Game of Life in the Elm programming language.
That article was originally written for version 0.12.3 and later updated for
0.14, but during the intervening span of time, Elm has matured significantly.
In the process, Elm has
{% fancylink %}
http://elm-lang.org/blog/farewell-to-frp
dropped its functional reactive roots
{% endfancylink %}
in favor of subscription-based concurrency.  Today, we will go through the same
exercise of writing the game of life, as a means of exploring the basics of a
simple modern Elm program.

##

If you have worked with Elm in the past, but several versions in the past, some
history may help frame some of the changes.  (N.B. While I was actively
following the discussions leading up to the release of version 0.15, I was
absent for some of the later versions, and, as such, this may not be a
perfectly accurate retelling.)  While the unifying concept of all changes being
a signal is very elegant, in practice, certain issues arose.  One such common
obstacle was with the behavior of
{% fancylink %}
https://groups.google.com/d/msg/elm-discuss/z1g8EEkgOBU/3uPXAU8GAwAJ
initial values in signals
{% endfancylink %},
especially when that value could be `undefined` coming from JavaScript.

Another major point of pain, at least in my experience, was the way in which
channels worked.  Since one of the major overhauls of the language going to
version 0.15 was the removal of this feature in favor of
{% fancylink %}
http://elm-lang.org/blog/announce/0.15
tasks, mailboxes, and addresses
{% endfancylink %},
it is safe to presume this was less than intuitive for many other users.  To
avoid belaboring the point, suffice to say, today all these concepts &mdash;
signals, channels, tasks, mailboxes, addresses &mdash; have been superceded by
two simple, complementary concepts: commands and subscriptions.

While there have been numerous other changes, they are largely tangential to
the conceptual core of Elm, so, let us begin, again.

## Rejuvenation

As we began in the original article, so we shall here: we simply want to draw
a static grid on the screen.  This will introduce us to a number of core
aspects of the language, without, hopefully, being overwhelming.

{% example_embed elm/static_grid.elm %}

Breaking this down, let us being with the declaration of the `main` function.
This is the function that is primarily responsible for producing the output we
want to render on the page.  This example uses an `Html.beginngerProgram`,
intended for simple programs that do not require the use of commands and
subscriptions.  In our particular case, we do not even need the use of the
`update`, since our model is predefined and never changes, so we simply set
that property to
{% fancylink %}
http://package.elm-lang.org/packages/elm-lang/core/5.1.1/Basics#Never
`never`
{% endfancylink %}, rather than supplying our own empty function.

To elaborate on the `beginngerProgram` function somewhat, it is provided as
part of the
{% fancylink %}
http://package.elm-lang.org/packages/elm-lang/html/latest
HTML package
{% endfancylink %}, takes a structure with the keys `model`, `view`, and
`update`.  The `view` function is responsible for taking our `model` and
converting it into an `Html msg`, the final markup we want to display on the
page.

In this instance, it is worthwhile to point out, we have defined a `type alias
Grid` for our model.  We could simply refer to our model throughout the program
as the `List (List Bool)` it ultimately is, but using domain-specific aliases
whenever possible is beneficial for the fluency and legibility of our code.
Remember:
{% fancylink %}
https://www.joelonsoftware.com/2000/04/06/things-you-should-never-do-part-i/
"It's harder to read code than to write it."
{% endfancylink %}

Finally, we should discuss the content of our `model` and `view` functions.
The former takes no arguments, and simply returns a nested list, fully
populated with the value `True`.  This represents a gird with every cell in an
enabled state.  The `view` function takes our model and, with the aid of some
helper functions, produces some very simple HTML for displaying our grid.  One
notable aspect of these helper functions is the way in which we use a straight
forward, declarative syntax for declaring something we are already familiar
with.

## Reification

The major difference necessary for having the ability to randomly seed our grid
with cells that are either enabled or disabled is switching out main function
to use the `Html.program` function.  This takes a structure, much like before,
but the `model` key has been substituted with the, significantly more powerful,
`init` key and adds a key for `subscriptions`.  While this example will not
make use of the `subscriptions` key, besides setting it to `always Sub.none`,
the way the
{% fancylink %}
http://package.elm-lang.org/packages/elm-lang/core/5.1.1/Random
`Random` library
{% endfancylink %}
work in Elm, we must make use of commands.  The resultant code follows:

{% example_embed elm/random_grid.elm %}

To expand upon the need for the full-fledged `Html.program` in this example, it
is necessary to understand the interplay between the `init` and `update`
functions, with the `Cmd Msg` being, passed between them in light of how random
number generation works.  Let us begin with that elucidation.  Since random
values must be generated at runtime, it is not possible to define a model with
random values in the same way we created a static one in the first example.  As
such, we statically define our generator, and the `Random.generate` call inside
the `init` function creates a `Cmd` we can later respond to.

This command is of type `Msg`, which only contains one possible value,
`Initialize Grid`.  When the `init` method returns, the existence of this
command will cause the `update` method to be called, in this case with our
`Msg Grid`, where the grid is fully populated with  randomly generated values.
The first argument to the `update` function is the current version of the model,
as kept track of by Elm, in this, the first item in the tuple returned by the
`init` function.

Since the `update` function returns with a `Cmd.none` as the second part of its
tuple, after having pulled the initial grid from its message, and there are no
further subscriptions, the program ends after one iteration of `update`.

## Recurrence

Finally, we have advanced to a point where adding generations is trivial.  This
requires only three, fairly straightforward, changes:

1. Add a `Tick Time` value to our `Msg` type.
2. Respond to the `Tick` message in our `update` function.
3. Define `subscriptions` creates `Tick` messages.

The `subscriptions` function ignores the `Grid` passed to it, since the passage
of time cares not about the current state of our simulation, and just emits a
new `Tick` message every second.  This is, in fact, perfectly legible from the
code itself, so I will let it speak for itself.

{% example_embed elm/game_of_life.elm %}

## Resolution

As you can see in the final example, most  of the changes are in support of
updating the state of the grid, not for wiring those updates themselves; that
part was trivial.  The ease of adding new paths, without interfering with
existing ones, is, I believe, one of the major improvements of the language.
In the past, I always felt as though I were building some `foldp` monstrosity,
even though it could be decomposed into separate parts that acted similar in
the ability to constrain changes.  Today, the pattern is explicit in the
structure of the program, making it apparent even to new users.

While it may be more cumbersome in larger programs to have so few points of
contact with the inner mechanisms that control dynamic elements, I can at least
conceptualize ways in which components can be combined to ameliorate this
potential issue.  In contrast, trying to expose signals from modules and hook
them together with channels felt very kludgey and limited at times.

Another key change is that Elm has become renderer agnostic.  In these examples,
I used the official HTML package, but I could have chosen SVG or the old
Graphics packages if I preferred.  In the past, I always found this a confusing
aspect of the platform.  Now that HTML is supported in this way, there is no
longer any need to explain to new users about the graphics libraries, again,
making it much easier for new users to get on boards.

I am, ultimately, happy I stepped away and let the language mature for some
time.  Also included in the versions are numerous enhancements, particularly in
the realms of tooling and error messages.  With the conceptual core conceivably
cemented, and future improvements aimed primarily at improving user experience,
if you have been reluctant to give Elm a try, I wholeheartedly recommend giving
it a try today.

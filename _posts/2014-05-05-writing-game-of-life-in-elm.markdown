---
layout: post
title: Writing Game of Life in Elm
date: 2014-05-05 22:59:00
tags: elm game-of-life
---

## Introduction

In this article, we will walk through the steps for writing an implementation
of
<a href="https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life" target="_blank">Conway's Game of Life</a>
in the
<a href="http://elm-lang.org/" target="_blank">Elm</a> programming language.

In doing so, we will learn about the basic principles involved with writing
programs in Elm, while grounding them in a concrete problem. We will be
building a single program in steps, so much of the source will be repeated
between the examples, but it will be more clear to present each step in its
entirety.

I first became interested in Elm after seeing Evan Czaplicki's
<a href="http://lanyrd.com/2013/mlocjs/sccwrp/" target="_blank">talk</a> from
mloc.js 2013, where he presented an overview of Elm and the compelling example
of how one would write a simple side-scroller in an extremely straight forward
fashion as a consequence of the core concept in Elm: signals.

Elm is a
<a href="https://en.wikipedia.org/wiki/Functional_reactive_programming" target="_blank">functional reactive programming</a>
language, a paradigm concerned with using an explicit model of time. Elm uses
signals as its abstraction of time-varying values, including various time
functions (e.g. `every second`), constants (e.g. `constant True`), which are
invariant over time, and user input (e.g. `Mouse.clicks`). These, and other,
signals can be combined and manipulated in various ways to achieve vastly
complex results, clearly and concisely. It is this expressive power of Elm
that I find especially interesting. The
<a href="http://elm-lang.org/learn/What-is-FRP.elm" target="_blank">overview of FRP</a>
on the Elm site is excellent resource for these core concepts.

For this reason, I chose Elm to explore Conway's Game of Life. Having seen that
Life can be written concisely, to an almost absurd degree, in
<a href="http://youtu.be/a9xAKttWgP4" target="_blank">APL</a>, it seems to me
to be a very interesting problem by which to compare different languages. I
have only dabbled with Elm in the past, writing a toy for
<a href="http://www.ludumdare.com/compo/ludum-dare-28/" target="_blank">LD 28</a>,
but have always wanted to spend some more time getting to know the language.

Without further ado, let us begin writing Conway's Game of Life.

## First Steps

We will begin by writing a very simple static grid, the foundation for our game.
I often begin writing Elm programs with all my signals planned out, interacting
in complex ways, since that seems the more interesting part of the problem, as
compared with some boringly simple display components. The fact of the matter
is, however, that, lacking in experience with static typing and the concepts of
signals, I often find myself in a mess and have to back out.

I, in fact, did that with this program. Several times. I believe I come to
understand the core concepts much more, but the fact remains: start with a
solid base and build on top of it. This first example will simply a grid of a
predetermined size. It has support for cells being turned on and off, but they
are all on to begin with.

{% example_embed elm/static_grid.elm %}

The crux of this program is that we want to turn a nested list of boolean
values (`List (List Bool)`) into an `Element`, one of two possible types for
the `main` function in an Elm program. We use the `Element` API to achieve this
in a few steps.

This first example is, beyond those points, only really interesting
syntactically. It should feel somewhat familiar to anyone who has worked with
other functional languages. One point worth mentioning is the forward function
application helper (`|>`). This helps clarify the program (at least to my eye),
when a value passes through a number of functions sequentially. The following
are equivalent: `(c (b a))` and `a |> b |> c`.

## Seeding the Grid

The next step is to take the grid we created in the first example and seed it
with randomly generated examples. In Elm, the `Random` component has three
functions, all of which are a `Signal`. This means that, we can no longer be
concerned with simply taking one value and mutating it into another, but
instead, with taking a signal and converting it into another signal. The `main`
function can also be of the type `Signal Element`, which, in a sense, becomes
the goal of our program - we have an input of type `Signal (List Int)` we
will be taking from `Random.list`, and we want to convert it into a
`Signal Element` that Elm can consume.

Herein lies a core concept - that of `map`ing a signal. The `map` function
has the type `(a -> b) -> Signal a -> Signal b`; it takes a function from type
`a` to type `b` and a signal of type `a` and returns a signal of type `b`. This
function is the primay means by which signals are converted from one type to
another.

As a consequence of the way `lift` works, by taking a function to convert a
signal, rewriting our static example to one that is randomly generated involves
very few steps. These are as follows:

1. Change the type of `main` from `Element` to `Signal Element`.
2. Write an `initialSeed` function of type `Siganl Random.Seed`
3. Write a `seededGrid` function of type `Random.Seed -> List (List Bool)`
4. Change `generateGrid` from `List (List Bool)` to `List Int -> List (List Bool)`
5. `map` our `seededGrid` function through our existing `renderGrid` function.

{% example_embed elm/random_grid.elm %}

We do write two other helper functions, `generateRow` and `groupInto`, but
neither change is essential for the example. In fact, the rendering we wrote
before, the helpers, and now the basic seeding never needs to change again.

These core input and output signals will remain constant, but we will have to
add some additional transitions in order to make life evolve.

## Adding Generations

This final piece of the puzzle is to make the grid evolve from one generation
to the next. Elm makes this exceptionally easy with its concept of past
dependent signals. The function `foldp`, of type
`(a -> b -> b) -> b -> Signal a -> Signal b` takes a function of two values,
a default value for the output signal, and an input signal. The function takes
two arguments: the current value of the input signal, and the past value (or
the default on the first event).

We can use this construct to take our `initialSeed` of `Signal (List (List Bool))`
and step it from generation to generation. This is, again, a comparatively simple
process, consisting primarily of the following steps:

1. Update the main function to make use of `foldp`.
2. Create a `step` function of type `List (List Bool) -> List (List Bool) -> List (List Bool)`.
3. Create an `evolve` function of type `List (List Bool) -> List (List Bool)`.

{% example_embed elm/game_of_life.elm %}

The only real nuance here is that we must `sampleOn seed (every second)`, which
updates the signal with the constant initial value. We use an empty default to
determine whether we should return the value from the seed, or whether we should
evlove the past value.

We use an `indexedMap` for the `evolve` function, because we will need to
have the index of the cell available when calling the `descend` function. Aside
from these points, it is simply gathering all the neighboring cells, filtering
invalid ones, counting live neighbors, and mapping to a new boolean value.

## Conclusion and Futher Steps

Elm is a wonderful and extremely expressive language, and my experiences with it
have been overwhelmingly positive. I think it is excellent for these types of
applications, and its core concepts are very solid. While neophytes may
struggle with the type system - I know I have had my share of problems - this
can be solved through experience. The community, moreover, is both
knowledgeable and willing to help. When I had a question, Evan responded almost
immediately and Jeff Smits elucidated my misconceptions.

In terms of this example, I think it is clear so long as the core concepts are
in place. It may be longer than the APL example, but I did also err on the side
of clarity over brevity. I have a feeling this could be condensed considerably
were that the goal of the exercise.

As such, the most interesting way to proceed with this start would be to add
interactive elements. Allowing a user to control things like cell size and
count, duration of a generation, to flip individuals cells, to pause the game.
The list could probaby go on and on, and combining signals from many different
inputs is one of the strengths of Elm. I intend on revisiting this example and
improving upon it in the near future, so wach out for that update.

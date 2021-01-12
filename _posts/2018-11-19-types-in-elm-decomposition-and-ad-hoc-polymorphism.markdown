---
layout: post
title: "Types in Elm: Decomposition and Ad Hoc Polymorphism"
date: 2018-11-19
tags:
  - elm
  - types
  - message decomposition
  - ad hoc polymorphism
  - specification
---

## New Beginnings

Since I originally learned about and tried Elm in 2013, a lot about the language
has changed. Elm and I have grown distant and close several times over the
years, each encounter being more pleasant than the last, but always ending
somewhat abruptly and falling a bit short. After our most recent reunion,
however, I feel as though the language has matured to a point where I am
empowered to really move forward with the larger projects I began several years
ago.

The purpose of this article is to elucidate some topics that were not abundantly
clear to me as an effectively new Elm user. It builds from real problems I have
encountered while writing real programs, and the solutions I devised to address
those issues.  These techniques revolve around how we compose and decompose
types to make our programs more maintainable.

before we move forward with the specifics, I would like to take a detour
through my history with Elm as a way to frame the present discussion.

<!--more-->

## Experience Thus Far

My first foray into
{% fancylink %}
  http://elm-lang.org/
  Elm
{% endfancylink %}
was in December of 2013, when I wrote a toy program during
{% fancylink %}
  http://ludumdare.com/compo/ludum-dare-28/
  Ludum Dare 28
{% endfancylink %}.
Since that time, I have always admired the language and enjoyed
{% fancylink %}
  {% link _posts/2017-05-22-revisiting-the-game-of-life-in-elm.markdown %}
  returning
{% endfancylink %}
to to it whenever I could, although that has only been to a
{% fancylink %}
  {% link _posts/2017-06-18-on-maintainability-gold-plating-the-game-of-life-in-elm.markdown %}
  limited extent
{% endfancylink %}.
During the past few years, the language has been heavily refined and the focus
has shifted from being heavily graphical and canvas-oriented to competing with
the other mainstream frameworks. Elm now shares some core features with those
frameworks that make it excellent for web application development, for instance
making use of a
{% fancylink %}
  https://package.elm-lang.org/packages/elm/virtual-dom/latest/
  virtual DOM
{% endfancylink %}
implementation for efficiently handling state updates.

Elm, however, also comes with other advantages that JavaScript frameworks are
incapable of offering. They type system provides both an unparalleled level of
safety, but also allows for dead code elimination that far surpasses anything
feasible in a highly dynamic language like JavaScript. The release of
{% fancylink %}
  http://elm-lang.org/blog/small-assets-without-the-headache
  0.19
{% endfancylink %}
earlier this year has brought me back to the language after an extended hiatus,
and the experience thus far has be extremely pleasant.

The last time I spent any significant time with Elm, I was able to make
progress on some projects of reasonable complexity, but ultimately hit a wall
where the future direction of my programs started to become unclear. This was
during the time when signals were the underlying principle, through when
{% fancylink %}
  https://elm-lang.org/blog/announce/0.15
  mailboxes
{% endfancylink %}
and addresses allowed us to create our own effects. In retrospect, the most
concise explanation I can now give of the problems I encountered at the time
were all related with having to managing my own effects. Maintaining a series
of reusable actions that could be triggered in different ways, and how to
properly factor an application quickly became insurmountable hurdles.

During those intervening versions, however, Elm
{% fancylink %}
  http://elm-lang.org/blog/farewell-to-frp
  moved on
{% endfancylink %}
from a functional reactive programming paradigm and, perhaps even more
importantly, added a runtime that
{% fancylink %}
  https://package.elm-lang.org/packages/elm/core/latest/Platform-Cmd
  manages effects.
{% endfancylink %}
This latter point, more than anything, has given us the ability to structure
our programs in a way that feels natural and easily maintainable. As I have
been writing a lot more Elm during the past month, I have stumbled upon a few
new, entirely tractable, problems that I would like to discuss.

## Decomposing Messages

One such problem I have encountered while writing Elm applications over a
certain size is an ever expanding `update` function that I am never really sure
how to properly factor. It is easy to have a separate function for each branch
of the `case` statement to handle each of the message types, but that can still
lead to an extremely unwieldy function right in the core of the application
logic. I typically want to be able to split this logic on a per-view basis, such
that all the updates are self-contained in the model module for that view,
rather than at the top level.

Consider the following example, designed to invoke two simple menus: `File` and
`Edit`. Each contains a number of commands, which are entirely handled by the
`update` function, but the primary concern here is the `msgToString` function.
We must also keep a separate `messages` list to be able to map over our type
variants, which is mildly inconvenient, but not in particular bothersome.

{% example_embed elm/StandardMsg.elm %}

But, what if we wanted to be able to treat the `File` commands and the `Edit`
commands separately? At first, it may not be apparent how to accomplish this
goal, but it is not only feasible, but rather simple. The major change is just
the following: modify our `Msg` type so that each of its variants takes a value.
This value is a separate type that is specific to the variant. In practice, this
looks like: `type Msg = File FileMsg | Edit EditMsg`. Then, we simply define our
two new `FileMsg` and `EditMsg` types to contain all their respective
subordinate messages.

The following implementation exhibits the exact same behavior as the original,
but using the `File` and `Edit` variants of our top-level `Msg` type to act
like containers for our `FileMsg` and `EditMsg` types, respectively. It also
shows how this technique can be used to factor out logic that is common to each
top-level message.

{% example_embed elm/DecomposedMsg.elm %}

We can see that this worked exactly as expected and already pays dividends at a
small scale. This becomes even more important in larger applications, where the
update function can be split up across many modules that encapsulate the logic
for specific parts of the application.

## Ad Hoc Polymorphism

This next technique somehow feels like abusing the type system, while still
working entirely within is boundaries. In particular, we are going to devise a
way to treat different types of things as through they were the same. We are
going to effectively define a method for achieving
{% fancylink %}
  https://en.wikipedia.org/wiki/Ad_hoc_polymorphism
  ad hoc polymorphism
{% endfancylink %}
in Elm.

The example I am using here will hopefully resonate with most readers: simple
form controls. Imagine we have radio buttons and checkboxes, which both have
a lot of shared behavior, but also the distinct behavior that one only allows
for a single selection, while the other allows for any number of selection. So
long as we do not need to mix these on the page, it is easy enough to define
them separately and simply `map` over the lists of each and composing the HTML
result afterwards, as in the following example.

This example has two simple type aliases for a `Radio` and a `Checkbox`. They
both share a common `label: String` field, but differ in that their `value`
fields have types of `String` and `List String` respectively. In this case, it
would not be impossible to simply allow radio buttons to have a list of values,
but, for the sake of argument, imagine such a solution were not tenable.

{% example_embed elm/StandardTypeAlias.elm %}

But what if we need to have a mixture of radios and checkboxes throughout our
form? We can do something horrifying, like having `firstRadio`, `secondRadio`,
`firstCheckbox`, and `secondCheckbox` functions, which certainly works in simple
cases, but not so much in the real world. What we really want, though, is to be
able to treat radios and checkboxes the same; we want
them to be polymorphic. Since Elm does not support
{% fancylink %}
  https://en.wikipedia.org/wiki/Type_class
  type classes
{% endfancylink %}
this must be impossible. There are
{% fancylink %}
  https://medium.com/@eeue56/why-type-classes-arent-importNotNiniant-in-elm-yet-dd55be125c81
  other ways
{% endfancylink %}
to work around this
{% fancylink %}
  https://github.com/elm/compiler/issues/38
  current limitation
{% endfancylink %},
but there it is also possible to leverage the type system to accomplish
something very similar.

This technique borrows its name from Eric Evan's book Domain-Driven Design,
although it takes on a very different meaning. Still, it is worth understanding
the origin of the term, so here is the original definition as an aside:

<blockquote>
  <p>
    A specification is a predicate that determines if an object does or does not
    satisfy some criteria. Many specifications are simple [...]. In cases where
    the rules are complex, the concept can be extended to allow simple
    specifications to be combined, just as predicates are combined with logical
    operators. [...] The fundamental pattern stays the same and provides a path
    from the simpler to more complex models.
  </p>
</blockquote>

In our example, instead of specifications being a predicate, they instead
function as an augment to some other type. This means we are able to have some
shared behavior in a base type and then add additional behavior to that type.
This is reminiscent of
{% fancylink %}
  https://elm-lang.org/docs/records#record-types
  extensible records
{% endfancylink %},
but also somewhat different.

We start by creating a single, higher-order type, a `Control` that will
encapsulate the shared behavior of both radios and checkboxes, specifically
having a `label` and a `spec` field. The `Specification` type is defined in the
same way as the decomposed messages in the first example, with the type
acting like a box for holding a specification. In this example, the `Radio` and
`Checkbox` types work as concrete implementations of a specification. Lastly,
we simply need to define our list of controls, write a view function to handle
them, and modify our other view functions slightly to also accept a
specification.

{% example_embed elm/PolymorphicTypeAlias.elm %}

As this example shows, we have found a way to treat checkboxes and radio
buttons as if they were they were simply controls. In practice, I have found
this to be extremely useful, albeit a little strange. There is a bit more
boilerplate in defining our list of `controls`, but other than a few
additional type constructors, it amounts to very little.

## Reductio Ad Minimum

These two techniques can significantly simplify certain aspects of an Elm
application. Decomposing messages to make our main `update` function easer to
understand at a glance by factoring out the concerns into separate functions
that can then be stored in separate modules. Using the ad hoc polymorphism
outlined above makes it possible to for us to combine related sets of data and
treat them as functionally equivalent. This could probably be abused, but in
reasonable situations, appears to be a safe technique to deploy.

One thing I often struggle with when writing Elm is making large-scale changes
to my types, such as the ones above. The way that types
{% fancylink %}
  https://guide.elm-lang.org/types/
  flow
{% endfancylink %}
through the application is one of the nicest aspects of working with Elm. While
greatly simplifying refactors by the compiler identifying and helping to fix
mistakes, the flow of types can have cascading effects during experimental
changes that are difficult to untangle. In these cases, my solution is to
construct an example that is reduced to the bare minimum of moving parts. The
examples in this article are exactly that: the result of my inability to
concretely understand how to accomplish these goals in a real application, and
me resorting to a scratch pad to work through them conceptually. Once I arrive
at a concrete implementation, I am then able to apply that to my actual
problem.

Often there is no recourse other than trimming away as much non-essential
information as possible to help me understand the issue at hand.

In conclusion, I want to reinforce that there is no better time than now to try
out Elm. The
{% fancylink %}
  https://guide.elm-lang.org/
  guide
{% endfancylink %}
is a great resource and a perfect place to start.

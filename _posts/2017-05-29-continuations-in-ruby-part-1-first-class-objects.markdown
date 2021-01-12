---
layout: post
title: 'Continuations in Ruby - Part 1: First Class Objects'
date: 2017-05-29
tags:
  - ruby
  - continuations
  - on lisp
---

## Caveat Emptor

This is the first in an ongoing part series exploring the possibilities
presented to the programmer when continuations are a first class part of a
language.  These articles follow Chapter 20 of Paul Graham's venerable treatise
{% fancylink %}
  http://www.paulgraham.com/onlisp.html
  On Lisp
{% endfancylink %}.

While a powerful semantic construct, there is no secret that continuations are,
for good reason,
{% fancylink %}
  http://okmij.org/ftp/continuations/against-callcc.html
  thoroughly reviled
{% endfancylink %}.
In short, give us the ability to store the state of a computation and return to
it at a later point in the execution of our program.  This form of non-local
return (or
{% fancylink %}
  http://rosettacode.org/wiki/Jump_anywhere#Ruby
  jump anywhere
{% endfancylink %})
can be compared to `goto` statements of old or `try`/`catch` semantics commonly
seen today.  Both of these language features, in fact, can be implemented in
terms of continuations, and in section 5.8.3 of
{% fancylink %}
  http://shop.oreilly.com/product/9780596516178.do
  The Ruby Programming Language
{% endfancylink %},
the authors construct a BASIC inspired `goto` function.  Today, when we `require
'continuation'`, the interpreter will kindly inform us that 'warning: callcc is
obsolete; use Fiber instead'.

With continuations framed in this way, it should go without saying that, under
no circumstances whatsoever, should these curios be used in anything with any
degree of seriousness.  Why, then, should should we even bother?  Sometimes,
the simple fact that we should not is enough to make it worthwhile.

<!--more-->

## The Basics

Because `callcc` is obsolete, the continuation library is not included by
default in Ruby.  Each example contained herein requires
`require 'continuation'` as a prelude before being able to call
{% fancylink %}
  https://ruby-doc.org/core-2.4.1/Kernel.html#method-i-callcc
  Kernel#callcc
{% endfancylink %}.
The `callcc` function takes a block, which is passed an instance of a
{% fancylink %}
  http://ruby-doc.org/core-2.4.1/Continuation.html
  continuation object
{% endfancylink %},
and ultimately returns whatever the block returns.  These first examples will
only run inside IRB, since they otherwise cause an infinite unwinding of the
stack (e.g. every time the continuation is `call`ed, execution moves up the
program, only to encounter the same `call` ad infinitum).

Here, we create a global variable in which we will store our continuation.  As
this example shows, we can call the continuation repeatedly, and it will return
whatever we pass into into the method.  The final key point in the
demonstration is the way in which subsequent computation is safely discarded.
In this case, the `+ 1` call does not result in the usual `TypeError: no
implicit conversion of Integer into String`.

{% highlight irb %}
>> $cont = nil
>>
>> "the call/cc returned #{callcc { |c| $cont = c; 'a' }}"
=> "the call/cc returned a"
>> $cont.call(:again)
=> "the call/cc returned again"
>> $cont.call(:thrice)
=> "the call/cc returned thrice"
>> $cont.call(:safely) + 1
=> "the call/cc returned safely"
{% endhighlight %}

As an aside, it is worth noting that it is possible to make IRB act more like
the interpreter proper.  Two ways to prevent it from taking control of the
stack and allowing these examples to run without looping indefinitely are:

1. Elide the calls onto one line (e.g `puts "the call/cc returned #{callcc { |c| $cont = c; 'a' }}"; $cont.call`)
2. Wrap the calls to `Kernel#callcc` and the `Continuation#call` inside a `begin`..`end` block

Our next example demonstrates that the stack is shared between continuations.
We can call either one, and receive successive numbers.

{% highlight irb %}
>> $cont1, $cont2 = nil
>>
>> -> (x = 0) {
?>   callcc do |cc|
?>     $cont1 = cc
?>     $cont2 = cc
?>   end
?>
?>   x += 1
?>   x
?> }[]
>>
>> $cont2.call
=> 2
>> $cont1.call
=> 3
{% endhighlight %}

## A Practical Example: Depth First Traversal

In this next example, we will implement a depth first traversal for trees
represented as nested arrays of values (inspired by the homoiconicity of Lisp).
Rather than using a traditional recursive method, we make use of continuations
to pause the calculation at appropriate points, only to restart it at any point
in the future.  `Tree#dft` processes the entire tree at once, storing
intermediate calculations (cf.
{% fancylink %}
  https://en.wikipedia.org/wiki/Thunk
  thunks
{% endfancylink %})
in the `saved` array, which are then processed after the current branch is
completed.

{% highlight ruby %}
class Tree
  attr_accessor :tree, :saved, :output

  def initialize(tree)
    self.tree = tree

    self.saved = []
    self.output = []
  end

  def dft
  	node = dft_node(tree)

  	return if node.nil?

  	output << node
  	restart
  end

	def dft_node(node = self.tree)
    return if node.nil?

    unless node.kind_of?(Array)
      node
    else
      restart if node.empty?

      callcc do |cc|
        self.saved = saved.unshift(-> { cc.call(dft_node(node.drop(1))) })
        dft_node(node.first)
      end
    end
  end

  def restart
    return if saved.empty?

    saved.first.tap { self.saved = saved.drop(1) }.call
  end
end
{% endhighlight %}

And the output is identical to what you would expect with the recursive solution.

{% highlight irb %}
>> tree = Tree.new([:a, [:b, [:d, :h]], [:c, :e, [:f, :i], :g]])
=> #<Tree:0x00557411a28a48 ...>
>> tree.dft
>> tree.output
=> [:a, :b, :d, :h, :c, :e, :f, :i, :g]
>>
>> tree = Tree.new([1, [2, [3, 6, 7], 4, 5]])
=> #<Tree:0x005574119c48b8 ...>
>> tree.dft
>> tree.output
=> [1, 2, 3, 6, 7, 4, 5]
{% endhighlight %}

The most interesting aspects of this implementation, however, is not simply that
it produces the expected result.  The first thing to notice, as Graham points
out, is the lack of any explicit iteration or recursion.  Control flow is
entirely handled through the partial calculations we store as continuations and
restart until we have completed the traversal.  "Search with continuations
represents a novel way of thinking about programs:  put the right code in the
stack, and get the result by repeatedly returning up through it."

The second novel feature of this implementation is that we are able to take
control of it using the `Tree#dft_node` and `Tree#restart` methods.  Once we
have an instance of a tree, we can take off as many nodes as we want.  It is
possible, in fact, to turn this implementation into a lazy enumerator with very
little effort.  This next figure displays the output when the flow is explicitly
handled by the caller.

{% highlight irb %}
>> tree = Tree.new([:a, [:b, [:d, :h]], [:c, :e, [:f, :i], :g]])
=> #<Tree:0x0055a9c66363a0 ...>
>> tree.dft_node
=> :a
>> tree.restart
=> :b
>> tree.restart
=> :d
>> tree.restart
=> :h
{% endhighlight %}

## Continuation Passing Style Without Macros

This article has glossed over a very key point:  Lisp does not actually have
continuations, and all these examples are taken from Scheme as a way to frame
an implementation of continuations in Lisp using macros.  This is accomplished
using macros, which, in Lisp, are statically interpolated, making it possible
to fall back on lexical scope and variable shadowing as the primary mechanisms
for implementing semantics similar to continuations.  Since metaprogramming in
Ruby is dynamically performed at runtime, we do not have the same facilities at
our disposal.  We will have to, instead, take a different approach to the
problem and, likely, abuse some language features to accomplish the same result.

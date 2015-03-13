---
layout: post
title: Hacking S-expressions into Ruby
date: 2015-02-26
tags:
  - ruby
  - s-expressions
  - array literals
  - lisp
  - hack
---

## Background

<a href="https://en.wikipedia.org/wiki/S-expression" target="_blank">S-expressions</a>
are a classic means of storing trees of data. Part of the original Lisp
specification, they have been a part of software engineering since the very
beginning. Other languages, notably Scheme and, more recently, Clojure, have
helped maintain the relevancy of this very simple means for representing data.

In the spirit of
<a href="https://en.wikipedia.org/wiki/Greenspun%27s_tenth_rule" target="_blank">Greenspun's tenth rule</a>,
we are going to attempt make first-class s-expressions in Ruby. There is
already a
<a href="http://rosettacode.org/wiki/S-Expressions#Ruby" target="_blank">nice implementation</a>
of s-expressions in Ruby, for reference, but they are not first-class, which
makes them less than ideal. As such, we are going to to see how far we can
push (read: abuse) the dynamic nature of the Ruby language, and investigate
just how much control we have over certain elements of its syntax.

For anyone more interested in the result than the journey, be warned that this
attempt will not be successful, but some interesting results will be found
along the road to ultimate failure.

##

## A Simple Hack

The most natural way for storing nested lists of data in Ruby, is its `Array`
class. We will be able to skip most of the important details, and simply need
to write a mechanism for calling an Array.

The following is a fairly trivial
<a href="https://en.wikipedia.org/wiki/Monkey-patch" target="_blank">duck punch</a>
on the `Array` class that introduces a new `Array#call` method. This method
treats the first item in the array as an operation to be performed, and the
second as the implicit receiver of that message. If the receiver responds to
the message, that method is called, with the rest of the original array as
arguments; if not, then the operation is called directly with the entire
remainder of the array as arguments.

{% highlight ruby %}
class Array
  def call
    return [] if empty?

    op = first
    receiver = drop(1).first

    if receiver.respond_to?(op)
      receiver.send(op, *drop(2))
    else
      send(op, drop(1))
    end
  end
end
{% endhighlight %}

This is a terribly incomplete implementation, and we cannot recommend it for
production software. Were it more correct, it would still not be advisable to
use for any realistic purposes. In spite of that realistic perspective, this
actually produces some decent results.

{% highlight irb %}
>> [].call
=> []

>> [:puts, 'foo'].call
foo
=> nil

>> [:+, 1, 2].call
=> 3

>> [:puts, [:class, []].call].call
=> Array
{% endhighlight %}

Being required to `call` each array after instantiation, however, is incredibly
suboptimal &emdash; from a standpoint of maintainability and legibility, of
course.  Perhaps it will be possible for us to be able to have this method
get called automatically under some circumstances. In order to do this, we will
need to investigate how arrays get instantiated and see if we can hook into
that process to streamline our s-expressions.

## Array Literals in Ruby

The first thing to try is overriding `Array#initialize`, which should be a
simple enough way to transform arrays into s-expressions (read: completely
break the functionality thereof). For this first pass, we will just add some
debugging output to verify that this is the correct place to hook in and abuse
Ruby.

{% highlight ruby %}
class Array
  alias orig_initialize initialize

  def initialize(*args)
    puts "This is where we break things"
    orig_initialize(*args)
  end
end
{% endhighlight %}

{% highlight irb %}
>> []
=> []
{% endhighlight %}

For some reason, the constructor function never gets called when using the
array literal syntax. Luckily, we can also manipulate the `Array::new` method,
so surely that must be the answer. Tapping into individual methods to check if
they are getting called will quickly become tedious, however, so first we should
factor out that process into a function.

{% highlight ruby %}
def observe_method(object, method)
  object.send(:alias_method, "orig_#{method}", method)

  object.send(:define_method, method) do |*args|
    name = "#{object}##{method}"

    puts  "#{name} args: "#{args.inspect}"

    send("orig_#{method}", *args).tap do |return_value|
      puts "return value is: #{return_value}"
    end
  end
end

observe_method(Array.singleton_class, :new)
{% endhighlight %}

Now, looking into the call to `Array::new`, we should expect to see some
debugging output.

{% highlight irb %}
>> []
=> []
>> %w()
=> []
>> %i()
=> []
{% endhighlight %}

Surely, `Kernel.Array`, `Array::[]`, `Array.to_a`, or `Array.to_ary` must get
called at some point during the instantiation of an array from the literal
syntax.

{% highlight ruby %}
observe_method(Kernel, :Array)
observe_method(Array.singleton_class, :[])
observe_method(Array, :to_a)
observe_method(Array, :to_ary)
{% endhighlight %}

{% highlight irb %}
>> []
Array.to_a args:
Array.to_a returns: ["[", "]", "\n"]
{% endhighlight %}

This result, in spite of not being at all what we were seeking or expecting, is
very interesting, indeed. We have finally found a method being invoked during
the instantiation of an array from the literal syntax, but it is an array
containing all the characters from our line of input. Very strange, indeed.

## Becoming Truly Desperate

Desperate times, desperate measures. Looking through the calls to specific
functions is all well and good, but does not give a holistic enough picture of
what is actually happening. Perhaps, we should observe every single method call
on every single object and class in the entire `ObjectSpace` of the `Class`
class. Surely, that will reveal something about array instantiation.

{% highlight ruby %}
def observe_all_methods(object)
  object.instance_methods(false).each { |method| observe_method(object, method) }
  object.methods(false).each { |method| observe_method(object.singleton_class, method) }
end

ObjectSpace.each_object(Class).each do |klass|
  observe_all_methods(klass)
end
{% endhighlight %}

{% highlight shell %}
[1]    27580 segmentation fault  irb
{% endhighlight %}

A not particularly surprising result. If we, however, limit it to the classes of
live objects in the session, we do get slightly better results.

{% highlight ruby %}
ObjectSpace.each_object().map { |o| o.class }.uniq.each do |klass|
  observe_all_methods(klass)
end
{% endhighlight %}

{% highlight irb %}
>> []
Array#[]= args:
return value is: []
Array#to_a args:
Array#to_s args:

[...]

return value is: [RubyToken::TkLBRACK]
return value is: [RubyToken::TkLBRACK]

[...]

return value is: RubyToken::TkLBRACK
Array#[] args:
return value is: RubyToken::TkRBRACK

[...]

Array#join args:
return value is: []
Array#inspect args:
return value is: []
=> []
Array#empty? args:
return value is: true
{% endhighlight %}

This is mostly garbage, but there are some interesting snippets amongst the
multitude of noise. Maybe we can abuse something in `RubyToken` to allow us to
intercept (and own) the normal array instantiation process. Unfortunately, this
has actually all been a red herring. The `RubyToken` module is a part of
<a href="http://ruby-doc.org/stdlib-2.2.0/libdoc/irb/rdoc/RubyToken.html" target="_blank">`irb`</a>,
which we conveniently neglected to mention are using to test the various
examples. We get no useful output trying the same hacks from within a ruby
script, and get different ones when we use `pry`. The one glimmer of hope was
naught but the interactive shell processing our commands.

## Some Final Probes

There are a couple more things we can try, but few avenues remain. We can look
at what Ruby does to our input string using `Ripper`, but that is not of any
real value in this case.

{% highlight irb %}
>> require 'ripper'
=> true
>> Ripper.lex("[]")
=> [[[1, 0], :on_lbracket, "["], [[1, 1], :on_rbracket, "]"]]
>> Ripper.sexp_raw("[]")
=> [:program, [:stmts_add, [:stmts_new], [:array, nil]]]
{% endhighlight %}

A more insightful approach could be to use `Kernel#set_trace_func` to see
exactly what happens internally during array instantiation.

{% highlight ruby %}
set_trace_func(-> (event, _, line, id, binding, classname) {
  printf "%8s %-2d %10s %8s\n", event, line, id, classname
},)

[]
{% endhighlight %}

{% highlight irb %}
c-return 1  set_trace_func   Kernel
    line 5
{% endhighlight %}

Here we see only one `line` event occurring on line 5, where the array is
instantiated. This is the final dead end.

## Conclusions

With no other avenues to explore, we must concede defeat. At some point, Ruby
really must be just magic. Realistically, of course, what appears to be
happening is quite the opposite. We have found a situation where Ruby is not as
flexible as we would like it to be (N.B. this is not pejorative). In the end,
our little edifice is built atop C, and we cannot always manipulate all aspects
of our Ruby code in ways that are stupid or downright dangerous.  Fortunately,
this exploration was not entirely in vain, for we learned about a few
interesting features of Ruby and the point at which you can no longer bend the
language.

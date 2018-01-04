---
layout: post
title: Privacy and Exposure, Gatekeepers and Privileged Consumers
date: 2018-01-03
tags:
  - ruby
  - visibility
  - refinements
---

## Encapsulation and Information Hiding

{% fancylink %}
  https://en.wikipedia.org/wiki/Information_hiding
  Encapsulation
{% endfancylink %}
and
{% fancylink %}
  https://en.wikipedia.org/wiki/Information_hiding
  information hiding
{% endfancylink %},
are well known principles in object-oriented programming, common mechanisms for
maintaining DRY code and enforcing the
{% fancylink %}
  https://en.wikipedia.org/wiki/Single_responsibility_principle
  single responsibility principle
{% endfancylink %}.
While these foundational elements imbue the programmer with significant
expressive power and are essential for writing software with possessing anything  more than a
semblance of maintainability, they sometimes introduce restrictions that are
ultimately antithetical to those goals.  We, the writers of code,  should,
therefore, have a solid understanding of not only the standard use of these core
object-oriented principles, but also, and, perhaps, more importantly, where they
break down in addition to how and when to work around them.

We will look at the ways in which we are able to subvert typical safety nets, and
this exploration of various means for exposing otherwise private members will
also serve as an introduction to some features of the Ruby programming language
less frequently encountered in day to day practice.  We will, ultimately,
introduce additional safety to objects that traditionally have little, in an
attempt to limit the use of our newfound powers for good.  Let us begin by
looking at the three levels of visibility available and how they are used via a
concrete, storybook example.

##

## Visibility or Protection

Ruby has three different levels of visibility, the two most common of which are
`public` and `private`.  Public members, as the name implies, are unequivocally
accessible to any and all callers.  Private members, on the other hand, much
like Penelope, have extremely restricted access, described in the official
documentation
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/doc/syntax/modules_and_classes_rdoc.html#label-Visibility
  section on visibility
{% endfancylink %}
as:

<blockquote>
  <p>
    The third visibility is <code>private</code>. A private method may not be
    called with a receiver, not even <code>self</code>. If a private method is
    called with a receiver a NoMethodError will be raised.
  </p>
</blockquote>

While not necessarily clear from that description, what this means is that
private members are only available in any context where they can be accessed
without a receiver, specifically in an instance of a class or any of its
subclasses.  A
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/doc/syntax/calling_methods_rdoc.html#label-Receiver
  separate document
{% endfancylink %}
explains explicit receivers: in summary, as long as the dot syntax is not
required, a private method may be called.

What is strange about private access in Ruby is its similarity to protected
access in most other object-oriented languages (e.g. C++, Java, C#), yet Ruby
also has protected members.  This leads to the question of what exactly that
means, and, fortunately, we can fall back on the official documentation.

<blockquote>
  <p>
    The second visibility is <code>protected</code>. When calling a protected
    method the sender must be a subclass of the receiver or the receiver must
    be a subclass of the sender. Otherwise a NoMethodError will be raised.
  </p>

  <p>
    Protected visibility is most frequently used to define <code>==</code> and
    other comparison methods where the author does not wish to expose an
    object's state to any caller and would like to restrict it only to inherited
    classes.
  </p>
</blockquote>

That definition, and its accompanying example, are opaque enough that that it warrants
looking at a simplified example.  Imagine we have two kinds of `Mammal`,
`Kitten`s and `Puppy`s, both of which are capable of `cuddle`ing.  In this sad
scenario, however, affection between species is nonexistent, so kittens and
puppies will never cuddle with each other.  This can be accomplished with the
use of protected methods.

{% highlight ruby %}
class Mammal
  def cuddle(other)
    [reaction, other.reaction]
  end
end

class Kitten < Mammal
  protected

  def reaction
    :purr
  end
end

class Puppy < Mammal
  protected

  def reaction
    :nuzzle
  end
end
{% endhighlight %}

{% highlight irb %}
>> gweeby, luxe, bella = Kitten.new, Kitten.new, Puppy.new
>> gweeby.cuddle(luxe)
=> [:purr, :purr]

>> gweeby.cuddle(bella)
NoMethodError: protected method `reaction' called for #<Puppy:0x00005581ee417790>
{% endhighlight %}

As you can see, our two kittens, Gweeby and Luxe, will happily share their
warmth, but Bella is disallowed from partaking.  To put protected access in
plain English, it allows different instances of the same class (including
superclasses) to access methods on each other.  In this example, both instances
of `Kitten` can call `reaction` on each other, but not on an instance of
`Puppy`.

## Ancestry or Injection

In a world more worth living in, while the animosity between dogs and cats may
yet persist generally, but there can also be exceptions to the rule, such as
when particular animals grew up in close proximity.  At this point, we will look
at how we can exploit the fact that Ruby violates the
{% fancylink %}
  https://en.wikipedia.org/wiki/Open/closed_principle
  open/closed principle
{% endfancylink %}
in order to realize this possibility.

The obvious approach, for many seasoned Ruby developers, would be to simply
fall back on the facilities Ruby provides for accessing non-public members,
namely the functionally equivalent approaches of `instance_eval` and `send`.

{% highlight irb %}
>> bella.instance_eval { reaction }
=> :nuzzle

>> bella.send(:reaction)
=> :nuzzle
{% endhighlight %}

While these approaches may be Good Enough™, we can do better by utilizing the
class ancestry of our kittens and puppies.  Inspecting the output from
{% fancylink %}
  https://ruby-doc.org/core-2.1.0/Module.html#method-i-ancestors
  `Module#ancestors`
{% endfancylink %},
we can see that our two classes, as expected, are nearly identical.

{% highlight irb %}
>> Kitten.ancestors
=> [Kitten, Mammal, Object, Kernel, BasicObject]

>> Puppy.ancestors
=> [Puppy, Mammal, Object, Kernel, BasicObject]

>> Kitten.ancestors.drop(1) == Puppy.ancestors.drop(1)
=> true
{% endhighlight %}

Including a module on a class will actually modify the ancestors of that class,
thereby affecting the path of method lookup.  For example, if we open the
`Puppy` class using `class_eval`, we can include an anonymous module, that
subsequently appears in the list of ancestors.

{% highlight irb %}
>> Puppy.class_eval { include Module.new }
>> Puppy.ancestors
=> [Puppy, #<Module:0x000055c94e207ca0>, Mammal, Object, Kernel, BasicObject]
{% endhighlight %}

This little bit of knowledge is not particularly useful by itself, since the
method lookup will stop at the `Puppy` class, where the `reaction` method is
still protected.  This can be more easily visualized by stating that our
classes for kitten and puppies are leafs in the object tree, which can only
be extended through subclassing, which is not desirable in this instance.  Were
only there some way to inject an module before the class in which our protected
method is defined.  Enter the
{% fancylink %}
  https://ruby-doc.org/core-2.1.0/doc/syntax/modules_and_classes_rdoc.html#label-Singleton+Classes
  singleton class
{% endfancylink %}.
A singleton class is a special, unique class that exists for each object.  The
easiest way, perhaps, to demonstrate how it operates is to again turn to our
class ancestry, but, this time, by using
{% fancylink %}
  https://ruby-doc.org/core-2.1.0/Object.html#method-i-singleton_class
  `Object#singleton_class`
{% endfancylink %}
method.

{% highlight irb %}
>> gweeby.singleton_class.ancestors
=> [#<Class:#<Kitten:0x000055f164658910>>, Kitten, Mammal, Object, Kernel, BasicObject]

>> bella.singleton_class.ancestors
=> [#<Class:#<Puppy:0x00005581ee417790>>, Puppy, Litter, Mammal, Object, Kernel, BasicObject]
{% endhighlight %}

Now we can see a point of inflection where we can potentially inject a shared
ancestor that will act as a <strong>gatekeeper</strong> of sorts; for example,
consider the following  module, called `Litter` to denote that mammals including
it have had close familial relations since an early age.

{% highlight ruby %}
module Litter
  protected

  def reaction
    super
  end
end
{% endhighlight %}

As is clear, this module does nothing other than proxy the call to `reaction`,
but, combined with the ability to open the singleton class, this gives us the
incredible ability to open protected methods to instances of certain other
objects as we see fit.  We can see, in the following example, that Gweeby and
Bella will cuddle, based on their being part of the same litter, while Luxe and
Bella will not.

{% highlight irb %}
>> gweeby.singleton_class.class_eval { include Litter }
>> bella.singleton_class.class_eval { include Litter }

>> gweeby.cuddle(bella)
=> [:purr, :nuzzle]

>> luxe.cuddle(bella)
NoMethodError: protected method `reaction' called for #<Puppy:0x00005581ee417790>
{% endhighlight %}

## Refinement or Asymmetry

We now have the means of exposing methods between two collaborating objects that
share an interface, in this case, the `#reaction` method.  Let us imagine a
world where kittens refuse to be cuddled unless they are the instigator in the
interaction.  Our injected gatekeepers cannot accommodate this asymmetrical
relationship; we will need to use a different means of exposing our protected
methods.  Here, we can make use of a language feature first introduced in Ruby
2.0, the
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/doc/syntax/refinements_rdoc.html
  refinement
{% endfancylink %}.

This seldom used feature gives up the ability to change class definitions within
the local context, rather than globally like a typical monkey patch.  The
particular rules for this locality are fairly complicated, but, most
importantly, the refined class is modified from the point at which the refined
module is used, to the end of the block or file.  The following example shows
how we can `refine` the `Puppy` class to make its `reaction` method available in
a `Kitten` instance.

{% highlight ruby %}
class Puppy
  protected

  def reaction
    :nuzzle
  end
end

module Instigator
  refine Puppy do
    public :reaction
  end
end

class Kitten
  using Instigator

  def cuddle(other)
    [reaction, other.reaction]
  end

  protected

  def reaction
    :purr
  end
end
{% endhighlight %}

{% highlight irb %}
>> Kitten.new.cuddle(Puppy.new)
=> [:purr, :nuzzle]
{% endhighlight %}

Now we have what may be termed a <strong>privileged consumer</strong>.  The
`Kitten` class may instigate interactions with the `Puppy` class, but no other
object may do the same.  This leads to some interesting consequences when we
make use of these intricacies in a more practical example.

## To Redact an Interface

This tale of mammalian intrigue has, thus far, provided us with an avenue for
the exploration of the building blocks of member access in Ruby, but, as yet,
has made no stride toward convincing us that this approach can be useful in the
real world.  Let us, then, consider a typical Rails application, with heavy use
of ActiveRecord throughout.  Much of this is inspired by the book
{% fancylink %}
  http://objectsonrails.com/
  Objects on Rails
{% endfancylink %},
by
{% fancylink %}
  http://www.virtuouscode.com/
  Avdi Grimm
{% endfancylink %}.
Therein, Grimm presents a series of refactorings that, over time, encapsulates
direct access to the database within the model layer, only exposing it to
consumers via a well defined interface.  Here, we will take a slightly different
approach, and use our newly minted concept of privileged consumers to bestow
access upon certain other objects.

Imagine, further, if you will, an application with complex authorization
requirements that cannot be simply defined in a single `Ability` class, a
pattern popularized by the
{% fancylink %}
  https://github.com/CanCanCommunity/cancancan
  cancancan gem
{% endfancylink %}.
Instead, we want to have a separate category of objects that mediate access to
the underlying models.  While we could simply decorate our models with objects
that perform our unsafe operations, we want to be able to programmatically
enforce this restriction.

We will first need to discuss protected class methods.  It may seem obvious that
it is possible to protect a method by simply placing it after the `protected`
call, but that is not so.

{% highlight ruby %}
class Protected
  protected

  def self.show
    :protected
  end
end
{% endhighlight %}

{% highlight irb %}
>> Protected.show
=> :protected
{% endhighlight %}

Instead, we can make use of the fact that, in Ruby, a class is simply an
instance of a
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Class.html
  `Class`
{% endfancylink %}.
Consequently, it too has a singleton class that is open for modification.  The
pattern for doing so inside the class definition is rather well known, namely
the colloquial `class << self` syntax.  In fact, the name of the method responsible
for programmatically generating class methods is
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Object.html#method-i-define_singleton_method
  `Object#define_singleton_method`
{% endfancylink %},
a remnant of the days of yore (pre Ruby 1.9.1) when this pattern was necessary to
metaprogram at the class level.

{% highlight ruby %}
class Protected
  class << self
    protected

    def show
      :protected
    end
  end
end
{% endhighlight %}

{% highlight irb %}
>> Protected.show
Traceback (most recent call last):
        2: from /home/sonny/.rbenv/versions/2.5.0/bin/irb:11:in `<main>'
        1: from (irb):11
NoMethodError (protected method `show' called for Protected:Class)
{% endhighlight %}

With this in hand, the first step toward protecting the query interface of our
objects will be to create a `Redactor` module that simply takes a class name and
a list of methods to hide from the outside world via use of the `protected`
method on the singleton class.

{% highlight ruby %}
module Redactor
  def redact!(klass, methods)
    klass.singleton_class.class_eval do
      methods.each { |method| protected method }
    end
  end
end
{% endhighlight %}

This module simply opens the singleton class of the class on which we want to
redact the methods, and, using
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Module.html#method-i-class_eval
  `Module#class_eval`
{% endfancylink %},
marks each method as protected.  The next piece of the puzzle is to define our
mediators, starting with the `BaseMediator`, which ensapsulate all the
complexity of redacting methods and refining them within the context of the
appropriate subclasses.

{% highlight ruby %}
class BaseMediator
  extend Redactor

  # http://guides.rubyonrails.org/active_record_querying.html#retrieving-objects-from-the-database
  QUERY_INTERFACE_METHODS = %i(
    find
    create_with
    distinct
    eager_load
    extending
    from
    group
    having
    includes
    joins
    left_outer_joins
    limit
    lock
    none
    offset
    order
    preload
    readonly
    references
    reorder
    select
    where
  )

  def self.redact_and_refine!(subclass)
    model = subclass.name.gsub(/Mediator$/, '').safe_constantize

    redact!(model, QUERY_INTERFACE_METHODS)

    Module.new do
      refine model.singleton_class do
        QUERY_INTERFACE_METHODS.each { |method| public method }
      end
    end
  end
end
{% endhighlight %}

The `redact_and_refine!` class macro has two primary responsibilities, as
indicated by its name:

  1.  Redact the methods we do not want to have exposed.
  2.  Create a module with a refinement that makes them public again.

Normally, we would want to simplify this for the subclass by using
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Class.html#method-i-inherited
  `Class::inherited`
{% endfancylink %},
but, in this case, we are unable to do so, since trying to call
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Module.html#method-i-using
  `Module::using`
{% endfancylink %}
from within a method results in the following error:
`RuntimeError: Module#using is not permitted in methods`.
We are, therefore, forced to have each subclass pull in its own refinement, such
as in the following `CustomerMediator` below.

{% highlight ruby %}
class CustomerMediator < BaseMediator
  using redact_and_refine!(self)

  def self.load(id)
    Customer.find(id)
  end
end
{% endhighlight %}

While not ideal, this is not an onerous task for significantly increased
safety.  Because the `CustomerMediator` is responsible for hiding the methods
inside the `Customer` model from the outside world, we must first load it.
Then, using that same class, we are able to access the `Customer::find` method,
but when we try to do so directly, we are greeted by a `NoMethodError` remarking
that the method is protected.

{% highlight irb %}
>> CustomerMediator
=> CustomerMediator

>> CustomerMediator.load(1)
   Customer Load (0.3ms)  SELECT  "customers".* FROM "customers" WHERE "customers"."id" = $1 LIMIT $2  [["id", 1], ["LIMIT", 1]]
=> #<Customer:0x0000559d5f12a4d8 id: 1>

>> Customer.load(1)
NoMethodError: protected method `find' called for Customer(id: integer):Class
{% endhighlight %}

## The Wall of Least Surprise

In a perfect world, we would want to provide a better error message for
consumers of our classes, rather than the generic default message.  This desire
to provide the developer with as easy an interface as possible is an example of
the
{% fancylink %}
  https://en.wikipedia.org/wiki/Principle_of_least_astonishment
  principle of least surprise
{% endfancylink %}.
Attempts to add this feature, however, are not forthcoming, because of the
dynamic dispatch semantics of Ruby.  Take, for instance, the following
modification on the existing `Redactor` module and `BaseMediator` class:

{% highlight ruby %}
module Redactor
  def redact!(klass, methods)
    methods.map do |method|
      redacted_method = "__#{method}_redacted".to_sym

      klass.singleton_class.class_eval do
        alias_method(redacted_method, method)
        protected redacted_method
      end

      klass.define_singleton_method(method) do |*args|
        begin
          public_send(redacted_method, *args)

        rescue NoMethodError => e
          raise e unless e.message =~ %r{^protected method `#{redacted_method}' called for #{klass.name}}
          raise SecurityError.new("#{klass.name} cannot be queried directly, please use #{klass.name}Mediator")
        end
      end

      redacted_method
    end
  end
end
{% endhighlight %}

{% highlight ruby %}
class BaseMediator
  def self.redact_and_refine!(subclass)
    model = subclass.name.gsub(/Mediator$/, '').safe_constantize

    redacted_methods = redact!(model, QUERY_INTERFACE_METHODS)

    Module.new do
      refine model.singleton_class do
        redacted_methods.each { |method| public method }
      end
    end
  end
end
{% endhighlight %}

The major difference here is that we alias the existing method we are redacting
and redefine the original method to wrap a call to the alias, catching the
default exception and raising a more helpful one.  The `BaseMediator` then makes
the new methods public, rather than the original, which is already a public
wrapper.  Where this fails is that we have no way to call the original method
while respecting its updated visibility.  The use of
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Object.html#method-i-public_send
  `Object#public_send`
{% endfancylink %}
fails, since it does not honor the refinement and believes that that method is
still protected, as can be seen in the following.

{% highlight irb %}
>> CustomerFinder.load(1)
SecurityError: Customer cannot be queried directly, please use CustomerMediator
{% endhighlight %}

Attempting to use either
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Object.html#method-i-send
  `Object#send`
{% endfancylink %}
or
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Object.html#method-i-send
  `Object#method`
{% endfancylink %}
to call the method directly both fail by ignoring the visibility rules
altogether.  As such, we cannot provide a better message by wrapping the call to
our redacted method with some exception handling.

Another approach worthy of attempt is to inspect, via
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Object.html#method-i-public_methods
  `Object#public_methods`
{% endfancylink %}
and
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/Object.html#method-i-protected_methods
  `Object#protected_methods`
{% endfancylink %},
which methods are available, but this also fails to produce the expected results.
The following example leads us to a better understanding of what is happening
behind the curtains when using refinements to modify method visibility.

{% highlight ruby %}
class Protected
  class << self
    protected

    def print
      :protected
    end
  end
end

module Publicize
  refine Protected.singleton_class do
    public :print
  end
end

class Public
  using Publicize

  def self.print
    Protected.public_methods.include?(:print) # false
    Protected.protected_methods.include?(:print) # true

    Protected.print # works
    Protected.public_send(:print) # fails
  end
end

Public.print
{% endhighlight %}

{% highlight shell %}
Traceback (most recent call last):
        2: from protection.rb:29:in `<main>'
        1: from protection.rb:25:in `print'
protection.rb:25:in `public_send': protected method `print' called for Protected:Class (NoMethodError)
{% endhighlight %}

When this script is run, the static call works, but the dynamic call fails.
The `Protected::print` method, moreover, is list as protected, not public, from
within the class using the refinement!  As a consequence of this final result, I
cannot recommend using refinements for modifying method visibility when there is
any intention to use dynamic dispatch or rely upon reflection.  Having
encountered this first hand, it is worth pointing out that this is, at least
indirectly, mentioned in the
{% fancylink %}
  https://ruby-doc.org/core-2.5.0/doc/syntax/refinements_rdoc.html#label-Indirect+Method+Calls
  documentation
{% endfancylink %}
for refinements:

<blockquote>
  <p>
    When using indirect method access such as <code>Kernel#send</code>,
    <code>Kernel#method</code> or <code>Kernel#respond_to?</code> refinements
    are not honored for the caller context during method lookup.
  </p>

  <p>
    This behavior may be changed in the future.
  </p>
</blockquote>

Since this leads to somewhat unexpected results, I have decided to start a
conversation about changing this behavior, which can be found
{% fancylink %}
  https://bugs.ruby-lang.org/issues/14252
  here
{% endfancylink %}.

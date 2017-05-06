---
layout: post
title: Using Defined Properties for Better AngularJS Directives
date: 2015-01-21
tags:
  - javascript
  - angularjs
  - architecture
  - dry
---

## On Directives

Directives in AngularJS are an exemplary solution for writing reusable
components in modern web applications. They allow us to encapsulate all the
messy business logic and expose a very clean, declarative interface to consumers
of the API. As with most tools for constructing abstractions, however,
directives have certain limitations that can lead to implementation details
leaking through, resulting in code that less
{% fancylink %}
https://en.wikipedia.org/wiki/DRY_principle
DRY
{% endfancylink %}
and, consequently, less maintainable.

There are, however, ways to work around these shortcomings and to build
simpler, more expressive interfaces to our directives. Leveraging a lesser known
feature of JavaScript, we can encapsulate additional details of our business
logic. This method is also well suited for building on top of third party
directives with a complex API by abstracting the details into a business
object. In doing so, our markup will become more in line with the ideal in
AngularJS, which
{% fancylink %}
https://docs.angularjs.org/guide/introduction
promotes declarative code
{% endfancylink %}
over imperative. Without further ado, let us look at the current situation and
how we can improve our directives.

##

## Motivation and Shortcomings

The original motivation for this method arose when working with
{% fancylink %}
https://angular-ui.github.io/bootstrap/#/tabs
tabs component
{% endfancylink %}
of AngularUI Bootstrap. Its `<tabset>` directive provides three settings with
clearly overlapping concerns: `active`, `select()`, and `deselect()`. This
redundancy forces users of the API to not only create functions in addition to
the `active` flag, but more importantly, to declare them in the markup. We
repeat this for all tabs in a given application, leading to additional
maintenance effort.

This example also exhibits a significant issue with directives and two-way
binding in AngularJS. If we want the active flag to be programmatically
determined, e.g. if we have push notifications from the server to affect the
active state of our tabs, we are required to use a `$watch` in our controller
to set the attribute on our object &mdash; something like the following:

{% highlight javascript %}
angular.controller("TabsController", ["$scope", "TabModel", function($scope, TabModel) {
  $scope.$watch(TabModel.activeFn, function(val) {
    $scope.isTabActive = val;
  });
}]);
{% endhighlight %}

This boilerplate quickly accumulates, making our controllers fatter than they
optimally should be. We could move this logic into our service layer, but that
only deflects, not fundamentally solves, the issue.  One may surmise that,
perhaps, instead we could supply a function, but the
{% fancylink %}
https://code.angularjs.org/1.3.10/docs/api/ng/service/$compile#-scope-
two-way binding
{% endfancylink %}
mechanism for directives requires that the property we specify be assignable.
As such, we cannot use our function as is to pass the value through the'
interface of the directive.

## A Solution

There is, however, a very simple way to circumvent both these issues with one
fairly small change.  Introduce the
{% fancylink %}
https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/defineProperty
Object.defineProperty
{% endfancylink %}
method, part of the ECMAScript-262 standard. This extremely powerful method
gives us the ability to define custom properties on an object and control
aspects of it otherwise not available, such as its enumerability and whether or
not it can be written. For our purposes, the most important functionality is
the ability to define custom setter and getter methods for our property in a
manner that is completely transparent to users of the object.

We write a wrapper function for instances of our tab models, which need not be
the same type of service. This wrapper defines an `active` property to handle
both activating and deactivating the tab. We can also extend the default
wrapper to do additional work for us. In this case, we add a `notify` method to
the `TabWrapper` class which prevents notifications from being displayed on the
currently active tab, but could also be used to perform other operations, such
as automatically triggering updates in the model.

{% highlight javascript %}
app.service("TabWrapper", function() {
  function TabWrapper(tabModel) {
    this.model = tabModel;

    Object.defineProperty(this, "active", {
      get: function() {
        return tabModel.active;
      },

      set: function(val) {
        if (val && tabModel.activate) {
          tabModel.activate();
        } else if (!val && tabModel.deactivate) {
          tabModel.deactivate();
        }

        tabModel.active = val;
      }
    });
  }

  TabWrapper.prototype.notify = function() {
    return !this.model.active &&
      this.model.notify &&
      this.model.notify();
  };

  return TabWrapper;
});
{% endhighlight %}

In short, what we have accomplished is hiding all the details of how our tabs
operate in our service layer without any of it leaking into our controllers or
templates. So long as our services follow the simple interface defined by
`TabWrapper`, they will function seamlessly.

N.B. Using a wrapper class is a somewhat naive way of accomplishing this
technique, but it works well enough for these purposes. For a comprehensive
treatment on the subject of object composition and extension in JavaScript, I
cannot recommend highly enough Reginald Braithwaite's treatise on the topic:
{% fancylink %}
https://leanpub.com/javascript-spessore/read
JavaScript Spessore
{% endfancylink %}.

## An Example

{% fancylink %}
http://plnkr.co/edit/7X66uV?p=preview
Open in Plunkr
{% endfancylink %}

Using the above service, we can construct a complete example of how this
process works. This example underscores all of the advantages discussed above.

{% highlight javascript %}
var app = angular.module("DefinedPropertyExample", ["ui.bootstrap"]);

app.service("TabModel", ["$timeout", function($timeout) {
  function TabModel() {
    this.active = false;
    this.notification = false;
  }

  TabModel.prototype.activate = function() {
    this.content = "Some lazy content";
  };

  TabModel.prototype.deactivate = function() {
    this.notification = false;

    var self = this;
    $timeout(function() {
      self.notification = true;
    }, Math.floor(Math.random() * 5000));
  };

  TabModel.prototype.notify = function() {
    return this.notification;
  };

  return TabModel;
}]);

app.controller("TabsCtrl", ["$scope", "TabModel", "TabWrapper", function($scope, TabModel, TabWrapper) {
  $scope.tabs = [];

  for (var i = 0; i < 5; i++) {
    $scope.tabs[i] = new TabWrapper(new TabModel());
  }
}]);
{% endhighlight %}

{% highlight html %}
<body ng-app="DefinedPropertyExample">
  <div ng-controller="TabsCtrl">
    <tabset>
      <tab ng-repeat="tab in tabs track by $index" active="tab.active">
        <tab-heading>
          Tab { { $index + 1 } }
          <span ng-if="tab.notify()">!</span>
        </tab-heading>

        { { tab.model.content } }
      </tab>
    </tabset>
  </div>
</body>
{% endhighlight %}

First, we create a service object to drive our tabs. This model conforms to the
interface we have specified, namely the `activate`, `deactivate`, and `notify`
methods, although our wrapper allows any or all of these to be omitted. The
`activate` method defines the content for our tab lazily, as though it were
being loaded from a server. The `deactivate` method resets any active
notification and creates a `$timeout` that will activate the notification
within five seconds, as though notifications were streaming from a server. And,
finally, the `notify` method simply returns the `notification` property, but
is written as a function so that it would be possible to easily extend it to
accumulate data from subordinate objects if ever necessary.

Our controller simply creates five of these tabs and wraps them. Our template
iterates over and displays them. We can see the first activate function operate
immediately, given the content being displayed in the first tab. After changing
tabs, we see an exclamation point appear next to any tabs with notifications,
which is then reset when reactivated (recall, this latter point is handled by
the wrapper).

## Conclusion

The markup is cleaner, the controller knows nothing about the tabs, and all our
business logic exists in more or less pure JavaScript objects. All these points
are massive gains for maintainability, but the latter merits some emphasis.
Pushing as much of our logic down into simple, decoupled objects facilitates
writing tests &mdash; a practice that can use as much facilitation as possible.
Ultimately, any time we can find abstractions of this nature, they will benefit
the long term viability of our AngularJS applications.

---
layout: post
title: Hooks in AngularJS Controllers
date: 2014-02-05
tags:
  - angularjs
  - architecture
---

## The Situation

Sometimes when working with nested scopes, you may encounter a situation in
which some scope action depends on the status of some arbitrarily nested
controller. This could be a multi-part form built from reusable components,
preventing the user from proceeding until complete, for example.

An architecture that allows scopes nested within another scope to influence the
life cycle of the latter has one primary advantage, namely, greater separation
of concerns. A nested controller can supply functions for data validation and
formatting, while the parent controller defines functions for navigation and
accumulation of results. This leads to better modularity, as the parent
controller is isolated from the implementation of nested controllers, while the
latter are able to be used modularly in more contexts.

<!--more-->

## A Simple Example

{% fancylink %}
http://plnkr.co/edit/QKzZZq?p=preview
Open in Plunkr
{% endfancylink %}

As the structure of the following example indicates, we have three controllers
- one that coordinates and two that handle user input. We have taken the
liberty of using
{% fancylink %}
http://underscorejs.org/
underscore
{% endfancylink %}
to simplify checking if all conditions are met.

Here, the `FormCheckboxCtrl` has no validation, but does coerce its results to
be human readable, while `FormTextInputCtrl` returns the text input and is
invalid if none is provided.

What remains is, simply, to make it work.

{% highlight html %}
{% raw %}
<body ng-app="HookExample">
  <div ng-controller="FormPageCtrl">
    <p>Please enter some text below.</p>

    <span ng-controller="FormCheckboxCtrl">
      <input type="checkbox" ng-model="checkbox" />
    </span>

    <span ng-controller="FormTextInputCtrl">
      <input type="text" ng-model="textInput" />
    </span>

    <div ng-show="showResults()">{{ $scope.results() }}</div>
  </div>
</body>
{% endraw %}
{% endhighlight %}

{% highlight javascript %}
var HookExample = angular.module("HookExample", []);

HookExample.controller("FormPageCtrl", function($scope, RegisterHook) {
  $scope.showResults = function() {
    return RegisterHook("isDataValid", $scope, _.every);
  };

  $scope.results = function() {
    return RegisterHook("getResults", $scope, function(results) {
      return results.join(" - ");
    });
  };
});

HookExample.controller("FormTextInputCtrl", function($scope) {
  $scope.isDataValid = function() {
    return $scope.textInput && $scope.textInput !== "";
  };

  $scope.getResults = function() {
    return $scope.textInput;
  };
});

HookExample.controller("FormCheckboxCtrl", function($scope) {
  $scope.getResults = function() {
    return $scope.checkbox ? "Yes" : "No";
  };
});
{% endhighlight %}

## A Hook Implementation

By recursively traversing the `$$childHead` and `$$nextSibling` properties of
the scope, we can give ask if any controller nested within the hierarchy wishes
to respond to the hook, thereby influencing the life cycle of our parent
controller.

{% highlight javascript %}
HookExample.factory("RegisterHook", function() {
  return function(name, scope, callback) {
    var results = [];

    (function traverse(scope) {
      if (!scope) {
        return;
      }

      if (_.(scope, name)) {
        results.push(scope[name]());
      }

      traverse(scope.$$childHead);
      traverse(scope.$$nextSibling);
    })(scope.$$childHead);

    return callback(results);
  }
});
{% endhighlight %}

This simple implemnation will look for and call the `name` function on any
scope, starting from the `$$childHead` of the scope passed in. Once all the
results have been accumulated, the `callback` is called with those results,
allowing for a nice functional interface, as in the case of passing in
`_.every`.

Since the callback is required in this naive implementation, it
would be possible to pass in `angular.noop` as the callback to discard the
results, thereby issuing some call to arbitrarily nested controllers. In that
case, however, a more reasonable approach would be to `$broadcast` an event.

## Hooks vs. Events vs. Services

When is this approach of registering hooks more appropriate than using events?
Primarily when you need to get the data back from the user via collaborating
controllers. The way event broadcasting requires an event to the child
controllers, each of which must call another event for the parent controller to
handle quickly becomes brittle.  In cases where the data is not transient, it
is likely best to use a service object to store all the data and have the
collaborators reference it directly.

That said, there is certainly still a place for hooks like the one outlined
above, but it is necessary to use it in appropriate situations. Littering our
code with hooks that would be best treated as services for their persistence or
events for their unidirectionality will not be an improvement.

But in cases where data transience and bidirectional collaboration between
controllers at different levels of nesting is present, hooks reign supreme by
exposing carefully selected points of interaction.

## Improvements

Herein, we have only examined a very simple hooking mechanism, which can
certainly be built out to have some additional interesting properties. Optional
callbacks and the ability to handle arguments would be straight forward
changes.  More interesting is the possibility to return more than just a single
function for accumulating results, but instead having a more robust interface.
This could include functionality akin to that in `ActiveRecord` callbacks,
wherein returning false prevents future hooks from running and prevents some
default action.

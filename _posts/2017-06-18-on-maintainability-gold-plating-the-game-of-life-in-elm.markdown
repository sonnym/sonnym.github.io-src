---
layout: post
title: 'On Maintainability: Gold Plating the Game of Life in Elm'
date: 2017-06-18
tags:
  - elm
  - game of life
  - maintenance
  - gold plating
---

## Launch Pad

In a previous
[article]({% link _posts/2017-05-22-revisiting-the-game-of-life-in-elm.markdown %}),
we explored how to write Conway's Game of Life in the Elm programming language.
This example was predicated on one from several years before and compared the
differences in Elm over the intervening period of time.  Today, we will add some
entirely unnecessary features to the simple version of the program.

This exercise in
{% fancylink %}
  https://en.wikipedia.org/wiki/Gold_plating_(software_engineering)
  gold plating
{% endfancylink %}
will serve as a means of probing what it feels like to add new features to an
already established Elm program; these microcosmic changes will, hopefully, be
reflective of maintaining larger applications in Elm.  Throughout the course of
this article, we will consider successive diffs, starting from the original
implementation, while moving toward the final version.

##

If you would like to see the full source code during any step of the process,
please refer to this
{% fancylink %}
  https://gist.github.com/sonnym/ddb7ef3d9d458d2d2e40bf4ef91b2da8
  gist
{% endfancylink %}.

## Unifying the Model

The first step we must undertake is collapsing the various top level variables,
namely `cellSize`, `columns`, and `rows`, into a single `Model`.  We also
incorporate the (previously hardcoded) empty `Grid` into our initial `model`
value.  This entire step would be unnecessary, were it not (conveniently)
omitted from the original implementation.  Generally speaking, it is safer to
include extra items in the `Model` structure, in the off chance they become
variable in the future, rather than having global variables.  This would be
substantially more important when working with modular code but would also vie
against common API considerations (i.e. in deciding what to keep private within
a module, as opposed to exposing through a public data structure).

Unifying the model is a somewhat messy operation, since it involves changing
several type annotations, but this is also very illustrative.  We can see how
higher level functions deal with the `Model` type, which flows down to lower
level functions, where it is decomposed piecemeal for functions that only need,
for instance, `grid` or `cellSize` fields.  This makes the flow of data through
our functions explicitly visible, from top to bottom.

{% highlight diff %}
diff --git 1/_examples/elm/game_of_life.elm 2/_examples/elm/game_of_life_gold_plated_step1.elm
index 8e9e4c6..58db25f 100644
--- 1/_examples/elm/game_of_life.elm
+++ 2/_examples/elm/game_of_life_gold_plated_step1.elm
@@ -9,10 +9,21 @@ import Html exposing (Html, Attribute, div, text)
 import Html.Attributes exposing (style)
 
 type alias Grid = List (List Bool)
+type alias Model =
+  { grid : Grid
+  , rows : Int
+  , columns : Int
+  , cellSize : Int
+  }
 type Msg = Initialize Grid | Tick Time
 
-cellSize = 5
-(columns, rows) = (35, 35)
+model : Model
+model =
+  { grid = [[]]
+  , cellSize = 5
+  , columns = 35
+  , rows = 35
+  }
 
 main =
   Html.program
@@ -22,33 +33,38 @@ main =
     , subscriptions = subscriptions
     }
 
-init : (Grid, Cmd Msg)
+init : (Model, Cmd Msg)
 init =
-  ([[]], Random.generate
-    Initialize
-    (Random.map (groupInto columns) (Random.list (rows * columns) Random.bool)))
+  (model, Random.generate
+     Initialize
+     (Random.map
+       (groupInto model.columns)
+       (Random.list (model.rows * model.columns) Random.bool)))
 
-view : Grid -> Html msg
-view grid = div [ ] (List.map row grid)
+view : Model -> Html msg
+view model = div [ ] (List.map (row model.cellSize) model.grid)
 
-update : Msg -> Grid -> (Grid, Cmd Msg)
+update : Msg -> Model -> (Model, Cmd Msg)
 update msg state =
   case msg of
-    Initialize initial -> (initial, Cmd.none)
+    Initialize initial ->
+      ({ state | grid = initial }, Cmd.none)
 
-    Tick _ -> (evolve state, Cmd.none)
+    Tick _ ->
+      ({ state | grid = evolve state }, Cmd.none)
 
-subscriptions : Grid -> Sub Msg
+subscriptions : Model -> Sub Msg
 subscriptions _ = Time.every Time.second Tick
 
-row : List Bool -> Html msg
-row row = div [ style [ ("clear", "both") ] ] (List.map cell row)
+row : Int -> List Bool -> Html msg
+row size row =
+  div [ style [ ("clear", "both") ] ] (List.map (cell size) row)
 
-cell : Bool -> Html msg
-cell on = div [ cellStyle on ] [ text " " ]
+cell : Int -> Bool -> Html msg
+cell size on = div [ cellStyle size on ] [ text " " ]
 
-cellStyle : Bool -> Attribute msg
-cellStyle on =
+cellStyle : Int -> Bool -> Attribute msg
+cellStyle cellSize on =
   style
     [ ("background", if on then "black" else "white")
     , ("width", toString cellSize ++ "px")
@@ -63,14 +79,14 @@ groupInto n lst =
   else
     (List.take n lst) :: (groupInto n (List.drop n lst))
 
-evolve : Grid -> Grid
-evolve generation =
+evolve : Model -> Grid
+evolve ({grid} as model) =
   List.indexedMap (\y row ->
     List.indexedMap (\x _ ->
-      descend generation x y) row) generation
+      descend model x y) row) grid
 
-descend : Grid -> Int -> Int -> Bool
-descend grid x y =
+descend : Model -> Int -> Int -> Bool
+descend {grid, rows, columns} x y =
   List.concatMap (\n -> List.map (\m -> (x + n, y + m))
                    [-1, 0, 1]) [-1, 0, 1]
     |> List.filter (\p -> (first p) > -1 && (first p) < columns &&
{% endhighlight %}

## Restarting the Simulation

The first feature we will add is the ability to restart the simulation.  This
is a fairly straightforward modification, and is the first illustration of the
ease with which new features can be added.  This is preformed in a few simple
steps:

  1. Add a new `Restart` type case to our `Msg` union type.
  2. Draw the button in our `view` functions, configured to generate our `Restart` message when clicked.
  3. Handle the `Restart` case in the `update` function.

This latter point did require the factoring of a separate `seed` function for
generating the command to repopulate the `grid` from the `init` function, but
that is more corollary than an integral aspect of adding this feature.  We also
needed to import some additional modules (and expose some additional functions
on those already imported).

(N.B. A cursory search regarding the terminology for particular concrete cases
of a union type appears to be
{% fancylink %}
  http://web.cs.ucla.edu/~palsberg/tba/papers/turbak-dimock-muller-wells-tic97.pdf
  virtual variant
{% endfancylink %},
though this is not part of the Elm vernacular.)

{% highlight diff %}
diff --git 1/_examples/elm/game_of_life_gold_plated_step1.elm 2/_examples/elm/game_of_life_gold_plated_step2.elm
index 58db25f..f2874ec 100644
--- 1/_examples/elm/game_of_life_gold_plated_step1.elm
+++ 2/_examples/elm/game_of_life_gold_plated_step2.elm
@@ -5,7 +5,8 @@ import Random
 import Time exposing (Time)
 import Tuple exposing (first, second)
 
-import Html exposing (Html, Attribute, div, text)
+import Html exposing (Html, Attribute, div, label, button, text)
+import Html.Events exposing (onClick)
 import Html.Attributes exposing (style)
 
 type alias Grid = List (List Bool)
@@ -15,7 +16,10 @@ type alias Model =
   , columns : Int
   , cellSize : Int
   }
-type Msg = Initialize Grid | Tick Time
+
+type Msg = Initialize Grid
+         | Tick Time
+         | Restart
 
 model : Model
 model =
@@ -34,15 +38,14 @@ main =
     }
 
 init : (Model, Cmd Msg)
-init =
-  (model, Random.generate
-     Initialize
-     (Random.map
-       (groupInto model.columns)
-       (Random.list (model.rows * model.columns) Random.bool)))
+init = (model, seed model.rows model.columns)
 
-view : Model -> Html msg
-view model = div [ ] (List.map (row model.cellSize) model.grid)
+view : Model -> Html Msg
+view model =
+  div [ ]
+    [ div [ ] [ button [ onClick Restart ] [ text "Restart Simulation" ] ]
+    , div [ ] (List.map (row model.cellSize) model.grid)
+    ]
 
 update : Msg -> Model -> (Model, Cmd Msg)
 update msg state =
@@ -53,9 +56,19 @@ update msg state =
     Tick _ ->
       ({ state | grid = evolve state }, Cmd.none)
 
+    Restart ->
+      (state, seed state.rows state.columns)
+
 subscriptions : Model -> Sub Msg
 subscriptions _ = Time.every Time.second Tick
 
+seed : Int -> Int -> Cmd Msg
+seed rows columns =
+  Random.generate Initialize
+     (Random.map
+       (groupInto columns)
+       (Random.list (rows * columns) Random.bool))
+
 row : Int -> List Bool -> Html msg
 row size row =
   div [ style [ ("clear", "both") ] ] (List.map (cell size) row)
{% endhighlight %}

## Controlling Grid Dimensions

Now, we come to the point where the initial step of unifying the model will
actually pay off.  Adding this feature, again, requires changes to the imports
section of the program, but otherwise simply adds code _without changing any
that has already been written_.  This point demands emphasis:  we are able to
add entirely new functionality without touching any of the pre-existing code,
making our program much more robust to change than many other languages (think
about how horrendous adding sliders for controlling the dimensions of the grid
in JavaScript could look).

Our additions, much like with the restart button, are of a very particular sort
(expect to see this pattern again):  update the `Msg` union type, write HTML to
send the new message, and handle the message in the `update` function.

This particular feature requires an `onChange` helper method, which is not
supplied by the Elm HTML library.  This is a consequence of the indeterminacy
in the type of values produced by the change event.  In this case, we want an
integer, but defer handling of parsing the value ourselves until the update
cycle—we could perform this type conversion during the initial event handler,
but this would be an issue for two reasons.  The first of which being the
inability to reuse the function easily; we would need a new one if we ever
wanted to handle floats.  Additionally, if our type conversion fails, for any
reason, we are unable to supply a reasonable default value (e.g. the current
value in the state of our application).

Another point of interest in the implementation of this simple feature is the
use of an additional `Dimension` union type.  A significant feature of Elm, as
fas as I am concerned, is this ability to combine union types in such a way
that promotes composability.  While not inherently obvious from this example, it
would be possible to extract a separate `Dimension` module, exposing this type,
and handling various responsibilities related to dimensions of the grid.  In
the `update` function, we could, instead of having a nested `case` statement on
the `Dimension`, call out to a function in our library, thereby reducing the
verbosity of the primary update cycle and encapsulating the detailed knowledge
of dimensionality.

It is also worth noting that the `update` function for the `UpdateSize` branch
makes use of the new `seed` function introduced to handle restarting the
simulation.  This is done to prevent a mismatch between the values of `rows`
and `columns`, as compared to the size of our `grid`, in the internal instance
of the `Model` structure that Elm passes around.  For clarity, imagine a
situation where the number of rows is updated, but not the contents of the
nested list structure:  this would have potential to yield nonsensical results,
especially in the case where the rows are decreased below their initial value.

{% highlight diff %}
diff --git 1/_examples/elm/game_of_life_gold_plated_step2.elm 2/_examples/elm/game_of_life_gold_plated_step3.elm
index f2874ec..07ff1c3 100644
--- 1/_examples/elm/game_of_life_gold_plated_step2.elm
+++ 2/_examples/elm/game_of_life_gold_plated_step3.elm
@@ -5,9 +5,11 @@ import Random
 import Time exposing (Time)
 import Tuple exposing (first, second)
 
-import Html exposing (Html, Attribute, div, label, button, text)
-import Html.Events exposing (onClick)
-import Html.Attributes exposing (style)
+import Json.Decode as Json
+
+import Html exposing (Html, Attribute, div, label, button, input, text)
+import Html.Events exposing (onClick, on, targetValue)
+import Html.Attributes as Attr exposing (style)
 
 type alias Grid = List (List Bool)
 type alias Model =
@@ -20,6 +22,9 @@ type alias Model =
 type Msg = Initialize Grid
          | Tick Time
          | Restart
+         | UpdateSize Dimension String
+
+type Dimension = Rows | Columns
 
 model : Model
 model =
@@ -44,6 +49,29 @@ view : Model -> Html Msg
 view model =
   div [ ]
     [ div [ ] [ button [ onClick Restart ] [ text "Restart Simulation" ] ]
+
+    , div [ ]
+      [ label [ ] [ text ("Grid Rows (" ++ toString model.rows ++ ")") ]
+      , input
+        [ Attr.type_ "range"
+        , Attr.value (toString model.rows)
+        , Attr.min "10"
+        , Attr.max "200"
+        , onChange (UpdateSize Rows)
+        ] [ ]
+      ]
+
+    , div [ ]
+      [ label [ ] [ text ("Grid Columns (" ++ toString model.columns ++ ")") ]
+      , input
+        [ Attr.type_ "range"
+        , Attr.value (toString model.columns)
+        , Attr.min "10"
+        , Attr.max "200"
+        , onChange (UpdateSize Columns)
+        ] [ ]
+      ]
+
     , div [ ] (List.map (row model.cellSize) model.grid)
     ]
 
@@ -59,6 +87,20 @@ update msg state =
     Restart ->
       (state, seed state.rows state.columns)
 
+    UpdateSize dim size ->
+      case dim of
+        Rows ->
+          let
+            rows = Result.withDefault state.rows (String.toInt size)
+          in
+            ({ state | rows = rows }, seed rows state.columns)
+
+        Columns ->
+          let
+            columns = Result.withDefault state.columns (String.toInt size)
+          in
+            ({ state | columns = columns }, seed state.rows columns)
+
 subscriptions : Model -> Sub Msg
 subscriptions _ = Time.every Time.second Tick
 
@@ -85,6 +127,10 @@ cellStyle cellSize on =
     , ("float", "left")
     ]
 
+onChange : (String -> msg) -> Attribute msg
+onChange tagger =
+  on "change" (Json.map tagger targetValue)
+
 groupInto : Int -> List a -> List (List a)
 groupInto n lst =
   if List.length lst == 0 then
{% endhighlight %}

## Population Density

The ability to change the density of cells in the active state when reseeding
the grid fits perfectly within the purview of gold plating, so we should add
that feature, as well.  The basic pattern, as seen in the previous two
examples, remains the same and will not be elaborated upon.

Instead, we should consider how our earlier decision to keep the `onChange`
function generic has allowed its reuse in this implementation.  Our new feature,
however, does have a much larger footprint than others, since the `density`
field must be propagated through any call to the `seed` function.  An
alternative function signature would simply take the model, rather than three
fields therefrom, but that is a point which could be argued either way and
would not decrease the footprint of this change.

We also rewrite the `seed` function, in light of its additional complexity,
using
{% fancylink %}
  http://package.elm-lang.org/packages/elm-lang/core/5.1.1/Basics#|%3E
  forward function application
{% endfancylink %},
for improved legibility.

{% highlight diff %}
diff --git 1/_examples/elm/game_of_life_gold_plated_step3.elm 2/_examples/elm/game_of_life_gold_plated_step4.elm
index 07ff1c3..944ed9e 100644
--- 1/_examples/elm/game_of_life_gold_plated_step3.elm
+++ 2/_examples/elm/game_of_life_gold_plated_step4.elm
@@ -17,12 +17,14 @@ type alias Model =
   , rows : Int
   , columns : Int
   , cellSize : Int
+  , density : Float
   }
 
 type Msg = Initialize Grid
          | Tick Time
          | Restart
          | UpdateSize Dimension String
+         | UpdateDensity String
 
 type Dimension = Rows | Columns
 
@@ -32,6 +34,7 @@ model =
   , cellSize = 5
   , columns = 35
   , rows = 35
+  , density = 0.5
   }
 
 main =
@@ -43,7 +46,7 @@ main =
     }
 
 init : (Model, Cmd Msg)
-init = (model, seed model.rows model.columns)
+init = (model, seed model.rows model.columns model.density)
 
 view : Model -> Html Msg
 view model =
@@ -72,6 +75,18 @@ view model =
         ] [ ]
       ]
 
+    , div [ ]
+      [ label [ ] [ text ("Population Density (" ++ toString model.density ++ ")") ]
+      , input
+        [ Attr.type_ "range"
+        , Attr.value (toString model.density)
+        , Attr.min "0"
+        , Attr.max "1"
+        , Attr.step ".01"
+        , onChange UpdateDensity
+        ] [ ]
+      ]
+
     , div [ ] (List.map (row model.cellSize) model.grid)
     ]
 
@@ -85,7 +100,7 @@ update msg state =
       ({ state | grid = evolve state }, Cmd.none)
 
     Restart ->
-      (state, seed state.rows state.columns)
+      (state, seed state.rows state.columns state.density)
 
     UpdateSize dim size ->
       case dim of
@@ -93,23 +108,29 @@ update msg state =
           let
             rows = Result.withDefault state.rows (String.toInt size)
           in
-            ({ state | rows = rows }, seed rows state.columns)
+            ({ state | rows = rows }, seed rows state.columns state.density)
 
         Columns ->
           let
             columns = Result.withDefault state.columns (String.toInt size)
           in
-            ({ state | columns = columns }, seed state.rows columns)
+            ({ state | columns = columns }, seed state.rows columns state.density)
+
+    UpdateDensity val ->
+      let
+        density = Result.withDefault state.density (String.toFloat val)
+      in
+        ({ state | density = density }, seed state.rows state.columns density)
 
 subscriptions : Model -> Sub Msg
 subscriptions _ = Time.every Time.second Tick
 
-seed : Int -> Int -> Cmd Msg
-seed rows columns =
-  Random.generate Initialize
-     (Random.map
-       (groupInto columns)
-       (Random.list (rows * columns) Random.bool))
+seed : Int -> Int -> Float -> Cmd Msg
+seed rows columns density =
+  Random.map (\n -> n < density) (Random.float 0 1)
+    |> Random.list (rows * columns)
+    |> Random.map (groupInto columns)
+    |> Random.generate Initialize
 
 row : Int -> List Bool -> Html msg
 row size row =
{% endhighlight %}

## Controlling Tick Rate

Changing the speed at which the simulation runs is as simple as can be.
Following the, by now, well established pattern, we can do so in just a few
short lines.  If anything, the use of additional functions from the `Time`
module are interesting.

{% highlight diff %}
diff --git 1/_examples/elm/game_of_life_gold_plated_step4.elm 2/_examples/elm/game_of_life_gold_plated_step5.elm
index 944ed9e..3ff7ae6 100644
--- 1/_examples/elm/game_of_life_gold_plated_step4.elm
+++ 2/_examples/elm/game_of_life_gold_plated_step5.elm
@@ -18,6 +18,7 @@ type alias Model =
   , columns : Int
   , cellSize : Int
   , density : Float
+  , tickRate : Int
   }
 
 type Msg = Initialize Grid
@@ -25,6 +26,7 @@ type Msg = Initialize Grid
          | Restart
          | UpdateSize Dimension String
          | UpdateDensity String
+         | UpdateTickRate String
 
 type Dimension = Rows | Columns
 
@@ -35,6 +37,7 @@ model =
   , columns = 35
   , rows = 35
   , density = 0.5
+  , tickRate = 1
   }
 
 main =
@@ -87,6 +90,18 @@ view model =
         ] [ ]
       ]
 
+    , div [ ]
+      [ label [ ] [ text ("Tick Rate (" ++ toString model.tickRate ++ " hz)") ]
+      , input
+        [ Attr.type_ "range"
+        , Attr.value (toString model.tickRate)
+        , Attr.min "1"
+        , Attr.max "10"
+        , Attr.step "1"
+        , onChange UpdateTickRate
+        ] [ ]
+      ]
+
     , div [ ] (List.map (row model.cellSize) model.grid)
     ]
 
@@ -122,8 +137,15 @@ update msg state =
       in
         ({ state | density = density }, seed state.rows state.columns density)
 
+    UpdateTickRate val ->
+      let
+        tickRate = Result.withDefault state.tickRate (String.toInt val)
+      in
+        ({ state | tickRate = tickRate }, Cmd.none)
+
 subscriptions : Model -> Sub Msg
-subscriptions _ = Time.every Time.second Tick
+subscriptions state =
+  Time.every (Time.millisecond * (1000 / (toFloat state.tickRate))) Tick
 
 seed : Int -> Int -> Float -> Cmd Msg
 seed rows columns density =
{% endhighlight %}

## Mouse Reactivity

Having reached a point where new functionality, of a kind, is as trivial to add
as possible, we will now move on to adding a slightly different feature.  In
this case, we will set any cell moused over to the on state.

This change affects a larger footprint, but is still fairly well contained.  We
need to pass `Int` values for row and column through the `row` and `cell`
functions, such that the latter is able to add them to the `onMouseOver`
attribute for the divs of individual cells.

We also need to write a, rather kludgy `setAt` helper function, for updating an
item at an arbitrary point in our nested list.  We will discuss some
implications revealed by this, seemingly tangential aspect, shortly

{% highlight diff %}
diff --git 1/_examples/elm/game_of_life_gold_plated_step5.elm 2/_examples/elm/game_of_life_gold_plated.elm
index 3ff7ae6..8689a89 100644
--- 1/_examples/elm/game_of_life_gold_plated_step5.elm
+++ 2/_examples/elm/game_of_life_gold_plated.elm
@@ -8,7 +8,7 @@ import Tuple exposing (first, second)
 import Json.Decode as Json
 
 import Html exposing (Html, Attribute, div, label, button, input, text)
-import Html.Events exposing (onClick, on, targetValue)
+import Html.Events exposing (onClick, onMouseOut, on, targetValue)
 import Html.Attributes as Attr exposing (style)
 
 type alias Grid = List (List Bool)
@@ -27,6 +27,7 @@ type Msg = Initialize Grid
          | UpdateSize Dimension String
          | UpdateDensity String
          | UpdateTickRate String
+         | ToggleCell Int Int
 
 type Dimension = Rows | Columns
 
@@ -102,7 +103,7 @@ view model =
         ] [ ]
       ]
 
-    , div [ ] (List.map (row model.cellSize) model.grid)
+    , div [ ] (List.indexedMap (row model.cellSize) model.grid)
     ]
 
 update : Msg -> Model -> (Model, Cmd Msg)
@@ -143,6 +144,9 @@ update msg state =
       in
         ({ state | tickRate = tickRate }, Cmd.none)
 
+    ToggleCell x y ->
+      ({ state | grid = setAt x y True state.grid }, Cmd.none)
+
 subscriptions : Model -> Sub Msg
 subscriptions state =
   Time.every (Time.millisecond * (1000 / (toFloat state.tickRate))) Tick
@@ -154,12 +158,19 @@ seed rows columns density =
     |> Random.map (groupInto columns)
     |> Random.generate Initialize
 
-row : Int -> List Bool -> Html msg
-row size row =
-  div [ style [ ("clear", "both") ] ] (List.map (cell size) row)
+row : Int -> Int -> List Bool -> Html Msg
+row size column row =
+  div
+    [ style [ ("clear", "both") ] ]
+    (List.indexedMap (cell size column) row)
 
-cell : Int -> Bool -> Html msg
-cell size on = div [ cellStyle size on ] [ text " " ]
+cell : Int -> Int -> Int -> Bool -> Html Msg
+cell size x y on =
+  div
+    [ cellStyle size on
+    , onMouseOut (ToggleCell x y)
+    ]
+    [ text " " ]
 
 cellStyle : Int -> Bool -> Attribute msg
 cellStyle cellSize on =
@@ -203,3 +214,11 @@ descend {grid, rows, columns} x y =
 valueAt : Int -> a -> List a -> a
 valueAt i default lst =
   Maybe.withDefault default (List.head (List.drop i lst))
+
+setAt : Int -> Int -> a -> List (List a) -> List (List a)
+setAt x y val lst =
+  let
+    inner = valueAt x [] lst
+    updated = (List.take y inner) ++ (val :: (List.drop (y + 1) inner))
+  in
+    (List.take x lst) ++ (updated :: List.drop (x + 1) lst)
{% endhighlight %}

## Discussion

At long last, behold the full example before we discuss it in more detail:

{% example_embed elm/0.15/game_of_life_gold_plated.elm %}

This is, unfortunately, somewhat of a mess—not for any fault of Elm.  The main
problem is having kept everything in a single file in an attempt to make the
example self-contained.  Imagine separating out the `view` function (in
conjunction with subordinates) and the `update` (with its helpers) into separate
modules, leaving only the core logic in main file.  Elm, in fact, is designed in
such a way to facilitate (and even encourage) this sort of structure.
Additionally, we should have also created a function for generating the range
inputs in the `view` function, but that was also skipped in favor of making each
diff atomic.

Now, we return to the earlier point about the `setAt` helper function.  This
little nuisance points to a structural issue with this program.  Specifically,
the use of lists for this implementation is, most likely, suboptimal.  Since we
often make use of non-sequential access (via `valueAt`) and, in the final form,
updates, we should have instead used Elm's
{% fancylink %}
  http://package.elm-lang.org/packages/elm-lang/core/5.1.1/Array
  Array module
{% endfancylink %}.
This should be expected to increase performance, based on the way in which the
two different data structures are
{% fancylink %}
  https://stackoverflow.com/a/37707812
  implemented internally
{% endfancylink %}.
That said, having to be aware of the implementation details of the standard
library of a language is never optimal, but, at a certain point, abstractions
at face value can only go so far.  Preference for lists over arrays has been
{% fancylink %}
  https://github.com/elm-lang/elm-plans/issues/13
  discussed
{% endfancylink %}
before, but the proposal was dropped for lack of actual benchmarks pointing
toward their universal superiority, and, as such, this potential optimization is
naught but conjecture without further investigation.

One last potential optimization worth exploring is the use of the
{% fancylink %}
  http://package.elm-lang.org/packages/elm-lang/html/2.0.0/Html-Lazy
  `HTML.Lazy`
{% endfancylink %}
module.  In some cursory experiments, excluded from this article, the inclusion
of lazy declarations in the various `view`, `row`, and `cell` functions did not
noticeably improve performance under strenuous configurations.

Overall, this example has admirably performed its task of giving us context
within which to modify an Elm program.  As evidenced by the increasingly
trivial, practically repetitive, nature of the modifications, it is fair to
presume changes will normally follow the same simple pattern of updating union
types, dispatching messages via the user interface, and handling these new
cases in the update cycle.  Some larger changes will necessitate changes to the
flow of data through the application (as seen during model unification and the
addition of mouse reactivity), but even these changes are mostly local in
scope.  As a consequence of strong type checking, Elm also ensures, at compile
time, that any such cascading change is handled by the developer.  From a
maintainability perspective, this makes a very compelling case for the Elm
programming language.

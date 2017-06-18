---
---
import List
import Random
import Time exposing (Time)
import Tuple exposing (first, second)

import Html exposing (Html, Attribute, div, text)
import Html.Attributes exposing (style)

type alias Grid = List (List Bool)
type Msg = Initialize Grid | Tick Time

cellSize = 5
(columns, rows) = (35, 35)

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

init : (Grid, Cmd Msg)
init =
  ([[]], Random.generate
    Initialize
    (Random.map (groupInto rows) (Random.list (rows * columns) Random.bool)))

view : Grid -> Html msg
view grid = div [ ] (List.map row grid)

update : Msg -> Grid -> (Grid, Cmd Msg)
update msg state =
  case msg of
    Initialize initial -> (initial, Cmd.none)

    Tick _ -> (evolve state, Cmd.none)

subscriptions : Grid -> Sub Msg
subscriptions _ = Time.every Time.second Tick

row : List Bool -> Html msg
row row = div [ style [ ("clear", "both") ] ] (List.map cell row)

cell : Bool -> Html msg
cell on = div [ cellStyle on ] [ text " " ]

cellStyle : Bool -> Attribute msg
cellStyle on =
  style
    [ ("background", if on then "black" else "white")
    , ("width", toString cellSize ++ "px")
    , ("height", toString cellSize ++ "px")
    , ("float", "left")
    ]

groupInto : Int -> List a -> List (List a)
groupInto n lst =
  if List.length lst == 0 then
    []
  else
    (List.take n lst) :: (groupInto n (List.drop n lst))

evolve : Grid -> Grid
evolve generation =
  List.indexedMap (\y row ->
    List.indexedMap (\x _ ->
      descend generation x y) row) generation

descend : Grid -> Int -> Int -> Bool
descend grid x y =
  List.concatMap (\n -> List.map (\m -> (x + n, y + m))
                   [-1, 0, 1]) [-1, 0, 1]
    |> List.filter (\p -> (first p) > -1 && (first p) < columns &&
                          (second p) > -1 && (second p) < rows &&
                          (not ((first p) == x && (second p) == y)))
    |> List.filter (\p -> (valueAt (first p) False
                            (valueAt (second p) [] grid)))
    |> List.length
    |> (\l -> ((valueAt x False (valueAt y [] grid))
                && l > 1 && l < 4) || l == 3)

valueAt : Int -> a -> List a -> a
valueAt i default lst =
  Maybe.withDefault default (List.head (List.drop i lst))

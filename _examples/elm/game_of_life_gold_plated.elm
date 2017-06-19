---
---
import List
import Random
import Time exposing (Time)
import Tuple exposing (first, second)

import Json.Decode as Json

import Html exposing (Html, Attribute, div, label, button, input, text)
import Html.Events exposing (onClick, onMouseOut, on, targetValue)
import Html.Attributes as Attr exposing (style)

type alias Grid = List (List Bool)
type alias Model =
  { grid : Grid
  , rows : Int
  , columns : Int
  , cellSize : Int
  , density : Float
  , tickRate : Int
  }

type Msg = Initialize Grid
         | Tick Time
         | Restart
         | UpdateSize Dimension String
         | UpdateDensity String
         | UpdateTickRate String
         | ToggleCell Int Int

type Dimension = Rows | Columns

model : Model
model =
  { grid = [[]]
  , cellSize = 5
  , columns = 35
  , rows = 35
  , density = 0.5
  , tickRate = 1
  }

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

init : (Model, Cmd Msg)
init = (model, seed model.rows model.columns model.density)

view : Model -> Html Msg
view model =
  div [ ]
    [ div [ ] [ button [ onClick Restart ] [ text "Restart Simulation" ] ]

    , div [ ]
      [ label [ ] [ text ("Grid Rows (" ++ toString model.rows ++ ")") ]
      , input
        [ Attr.type_ "range"
        , Attr.value (toString model.rows)
        , Attr.min "10"
        , Attr.max "200"
        , onChange (UpdateSize Rows)
        ] [ ]
      ]

    , div [ ]
      [ label [ ] [ text ("Grid Columns (" ++ toString model.columns ++ ")") ]
      , input
        [ Attr.type_ "range"
        , Attr.value (toString model.columns)
        , Attr.min "10"
        , Attr.max "200"
        , onChange (UpdateSize Columns)
        ] [ ]
      ]

    , div [ ]
      [ label [ ] [ text ("Population Density (" ++ toString model.density ++ ")") ]
      , input
        [ Attr.type_ "range"
        , Attr.value (toString model.density)
        , Attr.min "0"
        , Attr.max "1"
        , Attr.step ".01"
        , onChange UpdateDensity
        ] [ ]
      ]

    , div [ ]
      [ label [ ] [ text ("Tick Rate (" ++ toString model.tickRate ++ " hz)") ]
      , input
        [ Attr.type_ "range"
        , Attr.value (toString model.tickRate)
        , Attr.min "1"
        , Attr.max "10"
        , Attr.step "1"
        , onChange UpdateTickRate
        ] [ ]
      ]

    , div [ ] (List.indexedMap (row model.cellSize) model.grid)
    ]

update : Msg -> Model -> (Model, Cmd Msg)
update msg state =
  case msg of
    Initialize initial ->
      ({ state | grid = initial }, Cmd.none)

    Tick _ ->
      ({ state | grid = evolve state }, Cmd.none)

    Restart ->
      (state, seed state.rows state.columns state.density)

    UpdateSize dim size ->
      case dim of
        Rows ->
          let
            rows = Result.withDefault state.rows (String.toInt size)
          in
            ({ state | rows = rows }, seed rows state.columns state.density)

        Columns ->
          let
            columns = Result.withDefault state.columns (String.toInt size)
          in
            ({ state | columns = columns }, seed state.rows columns state.density)

    UpdateDensity val ->
      let
        density = Result.withDefault state.density (String.toFloat val)
      in
        ({ state | density = density }, seed state.rows state.columns density)

    UpdateTickRate val ->
      let
        tickRate = Result.withDefault state.tickRate (String.toInt val)
      in
        ({ state | tickRate = tickRate }, Cmd.none)

    ToggleCell x y ->
      ({ state | grid = setAt x y True state.grid }, Cmd.none)

subscriptions : Model -> Sub Msg
subscriptions state =
  Time.every (Time.millisecond * (1000 / (toFloat state.tickRate))) Tick

seed : Int -> Int -> Float -> Cmd Msg
seed rows columns density =
  Random.map (\n -> n < density) (Random.float 0 1)
    |> Random.list (rows * columns)
    |> Random.map (groupInto columns)
    |> Random.generate Initialize

row : Int -> Int -> List Bool -> Html Msg
row size column row =
  div
    [ style [ ("clear", "both") ] ]
    (List.indexedMap (cell size column) row)

cell : Int -> Int -> Int -> Bool -> Html Msg
cell size x y on =
  div
    [ cellStyle size on
    , onMouseOut (ToggleCell x y)
    ]
    [ text " " ]

cellStyle : Int -> Bool -> Attribute msg
cellStyle cellSize on =
  style
    [ ("background", if on then "black" else "white")
    , ("width", toString cellSize ++ "px")
    , ("height", toString cellSize ++ "px")
    , ("float", "left")
    ]

onChange : (String -> msg) -> Attribute msg
onChange tagger =
  on "change" (Json.map tagger targetValue)

groupInto : Int -> List a -> List (List a)
groupInto n lst =
  if List.length lst == 0 then
    []
  else
    (List.take n lst) :: (groupInto n (List.drop n lst))

evolve : Model -> Grid
evolve ({grid} as model) =
  List.indexedMap (\y row ->
    List.indexedMap (\x _ ->
      descend model x y) row) grid

descend : Model -> Int -> Int -> Bool
descend {grid, rows, columns} x y =
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

setAt : Int -> Int -> a -> List (List a) -> List (List a)
setAt x y val lst =
  let
    inner = valueAt x [] lst
    updated = (List.take y inner) ++ (val :: (List.drop (y + 1) inner))
  in
    (List.take x lst) ++ (updated :: List.drop (x + 1) lst)

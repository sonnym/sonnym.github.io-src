---
---
import List
import Random

import Html exposing (Html, Attribute, div, text)
import Html.Attributes exposing (style)

type alias Grid = List (List Bool)
type Msg = Initialize Grid

cellSize = 5
(columns, rows) = (35, 35)

main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = always Sub.none
    }

init : (Grid, Cmd Msg)
init =
  ([[]], Random.generate
    Initialize
    (Random.map (groupInto rows) (Random.list (rows * columns) Random.bool)))

view : Grid -> Html msg
view grid = div [ ] (List.map row grid)

update : Msg -> Grid -> (Grid, Cmd Msg)
update msg _ =
  case msg of
    Initialize initial -> (initial, Cmd.none)

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

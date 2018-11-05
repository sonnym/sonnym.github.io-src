---
---
import List

import Html exposing (Html, Attribute, div, text)
import Html.Attributes exposing (style)

type alias Grid = List (List Bool)

cellSize = 5
(columns, rows) = (35, 35)

main = Html.beginnerProgram { model = model, view = view, update = never }

model : Grid
model = List.repeat rows (List.repeat columns True)

view : Grid -> Html msg
view grid = div [ ] (List.map row grid)

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

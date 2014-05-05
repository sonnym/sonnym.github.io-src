import Random

cellSize = 5
(columns, rows) = (35, 35)

main : Signal Element
main = lift renderGrid seed

seed : Signal [[Bool]]
seed =
  columns * rows
    |> constant
    |> Random.floatList
    |> lift generateGrid

generateGrid : [Float] -> [[Bool]]
generateGrid seeds = map generateRow (groupInto rows seeds)

generateRow : [Float] -> [Bool]
generateRow seeds = map (\n -> n > 0.5) seeds

renderGrid : [[Bool]] -> Element
renderGrid grid =
  grid
    |> map renderRow
    |> map (flow right)
    |> flow down
    |> container (cellSize * columns) (cellSize * rows) topLeft

renderRow : [Bool] -> [Element]
renderRow row = map renderCell row

renderCell : Bool -> Element
renderCell on =
  spacer cellSize cellSize
    |> color (if on then (rgb 0 0 0) else (rgb 255 255 255))

groupInto : Int -> [a] -> [[a]]
groupInto groups initial =
  let
    len = length initial
    n = div len groups
  in
    if | len == 0 -> []
       | otherwise -> (take n initial) :: (groupInto (groups - 1) (drop n initial))

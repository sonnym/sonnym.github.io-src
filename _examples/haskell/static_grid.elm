cellSize = 5
(columns, rows) = (35, 35)

main : Element
main = renderGrid generateGrid

generateGrid : [[Bool]]
generateGrid = repeat rows (repeat columns True)

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

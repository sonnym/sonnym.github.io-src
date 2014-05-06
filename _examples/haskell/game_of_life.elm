import Array (Array, fromList, toList, getOrFail, indexedMap)
import Random

cellSize = 5
(columns, rows) = (35, 35)

main : Signal Element
main = sampleOn (every second) seed |> foldp (step) [[]] |> lift renderGrid

seed : Signal [[Bool]]
seed =
  columns * rows
    |> constant
    |> Random.floatList
    |> lift generateGrid

step : [[Bool]] -> [[Bool]] -> [[Bool]]
step current past = if (isEmpty (head past)) then current else (evolve past)

generateGrid : [Float] -> [[Bool]]
generateGrid seeds = map generateRow (groupInto rows seeds)

generateRow : [Float] -> [Bool]
generateRow seeds = map (\n -> n > 0.5) seeds

evolve : [[Bool]] -> [[Bool]]
evolve grid =
  let generation = fromList (map fromList grid)
  in  generation
    |> indexedMap (\y row -> indexedMap
                    (\x _ -> descend generation x y) row)
    |> toList
    |> map toList

descend : Array (Array Bool) -> Int -> Int -> Bool
descend generation x y =
  concatMap (\n -> map (\m -> (x + n, y + m)) 
              [-1, 0, 1]) [-1, 0, 1]
    |> filter (\p -> (fst p) > -1 && (fst p) < columns &&
                     (snd p) > -1 && (snd p) < rows &&
                     (not ((fst p) == x && (snd p) == y)))
    |> filter (\p -> (getOrFail (fst p)
                       (getOrFail (snd p) generation)) == True)
    |> length
    |> (\l -> ((getOrFail x (getOrFail y generation))
                && l > 1 && l < 4) || l == 3)

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
       | otherwise -> (take n initial) :: 
                        (groupInto (groups - 1) (drop n initial))

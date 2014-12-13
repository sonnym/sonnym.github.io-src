import Signal ((<~), Signal)
import Signal

import List ((::))
import List

import Time
import Random

import Color (rgb)
import Graphics.Element (Element, flow, right, down, container, topLeft, spacer, color)

cellSize = 5
(columns, rows) = (50, 50)

main : Signal Element
main =
  Signal.sampleOn (Time.every Time.second) (seededGrid <~ initialSeed)
    |> Signal.foldp (step) [[]]
    |> Signal.map renderGrid

step : List (List Bool) -> List (List Bool) -> List (List Bool)
step current past = if (List.isEmpty (List.head past)) then current else (evolve past)

initialSeed : Signal Random.Seed
initialSeed = (\(time, _) -> Random.initialSeed (round time)) <~ Time.timestamp (Signal.constant ())

seededGrid : Random.Seed -> List (List Bool)
seededGrid seed =
  let (lst, _) = Random.generate (Random.list (columns * rows) (Random.int 0 1)) seed
  in generateGrid lst

generateGrid : List Int -> List (List Bool)
generateGrid seeds = List.map generateRow (groupInto rows seeds)

generateRow : List Int -> List Bool
generateRow seeds = List.map (\n -> n == 1) seeds

evolve : List (List Bool) -> List (List Bool)
evolve generation =
  List.indexedMap (\y row ->
    List.indexedMap (\x _ ->
      descend generation x y) row) generation

descend : List (List Bool) -> Int -> Int -> Bool
descend grid x y =
  List.concatMap (\n -> List.map (\m -> (x + n, y + m))
                   [-1, 0, 1]) [-1, 0, 1]
    |> List.filter (\p -> (fst p) > -1 && (fst p) < columns &&
                          (snd p) > -1 && (snd p) < rows &&
                          (not ((fst p) == x && (snd p) == y)))
    |> List.filter (\p -> (itemAt (fst p)
                            (itemAt (snd p) grid)) == True)
    |> List.length
    |> (\l -> ((itemAt x (itemAt y grid))
                && l > 1 && l < 4) || l == 3)

renderGrid : List (List Bool) -> Element
renderGrid grid =
  grid
    |> List.map renderRow
    |> List.map (flow right)
    |> flow down
    |> container (cellSize * columns) (cellSize * rows) topLeft

renderRow : List Bool -> List Element
renderRow row = List.map renderCell row

renderCell : Bool -> Element
renderCell on =
  spacer cellSize cellSize
    |> color (if on then (rgb 0 0 0) else (rgb 255 255 255))

itemAt : Int -> List a -> a
itemAt i lst = List.head (List.drop i lst)

groupInto : Int -> List a -> List (List a)
groupInto groups initial =
  let
    len = List.length initial
    n = len // groups
  in
    List.repeat groups []
      |> List.indexedMap (\i _ ->
          List.take n (List.drop (n * i) initial))

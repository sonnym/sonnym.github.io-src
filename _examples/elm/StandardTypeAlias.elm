---
---
import Browser
import Html exposing (Html)

type alias Radio =
  { label: String, selected: String}

type alias Checkbox =
  { label: String, selected: List String }

radios : List Radio
radios =
  [ Radio "First Radio" "First Selection"
  , Radio "Second Radio" "Second Selection"
  ]

checkboxes : List Checkbox
checkboxes =
  [ Checkbox "First Checkbox" [ "First Selection One", "First Selection Two" ]
  , Checkbox "Second Checkbox" [ "Second Selection One", "Second Selection Two" ]
  ]

main = Browser.sandbox
  { init = (), update = identity, view = view }

view : () -> Html (() -> ())
view nothing =
  div (List.append
    (List.map radio radios)
    (List.map checkbox checkboxes))

radio : Radio -> Html msg
radio {label, selected} =
  div [ (Html.text (label ++ ": " ++ selected)) ]

checkbox : Checkbox -> Html msg
checkbox {label, selected} =
  div [ (Html.text (label ++ ": " ++ (String.join ", " selected))) ]

div : List (Html msg) -> Html msg
div = Html.div []

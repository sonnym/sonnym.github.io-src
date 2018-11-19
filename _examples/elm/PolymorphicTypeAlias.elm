---
---
import Browser
import Html exposing (Html)

type Specification
  = RadioSpec Radio
  | CheckboxSpec Checkbox

type alias Control =
  { label: String, spec: Specification }

type alias Radio =
  { selected: String }

type alias Checkbox =
  { selected: List String }

controls : List Control
controls =
  [ Control
      "First Radio"
      (RadioSpec (Radio "First Selection"))

  , Control
      "First Checkbox"
      (CheckboxSpec (Checkbox [ "First Selection One", "First Selection Two" ]))

  , Control
      "Second Radio"
      (RadioSpec (Radio "Second Selection"))

  , Control
      "Second Checkbox"
      (CheckboxSpec (Checkbox [ "Second Selection One", "Second Selection Two" ]))
  ]

main = Browser.sandbox
  { init = (), update = identity, view = view }

view : () -> Html (() -> ())
view nothing =
  div (List.map control controls)

control : Control -> Html msg
control ({spec} as ctrl) =
  case spec of
    RadioSpec radioSpec -> radio ctrl radioSpec
    CheckboxSpec checkboxSpec -> checkbox ctrl checkboxSpec

radio : Control -> Radio -> Html msg
radio {label} {selected} =
  div [ (Html.text (label ++ ": " ++ selected)) ]

checkbox : Control -> Checkbox -> Html msg
checkbox {label} {selected} =
  div [ (Html.text (label ++ ": " ++ (String.join ", " selected))) ]

div : List (Html msg) -> Html msg
div = Html.div []

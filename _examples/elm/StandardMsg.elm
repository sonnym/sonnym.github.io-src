---
---
import Browser
import Html exposing (Html)
import Html.Events as Events

type alias Model = String

type Msg
  = FileNew
  | FileOpen
  | FileSave
  | FilePrint
  | FileQuit
  | EditUndo
  | EditRedo
  | EditCopy
  | EditCut
  | EditPaste

main = Browser.sandbox
  { init = "", update = update, view = view }

update : Msg -> Model -> Model
update msg model = msgToString msg

view : Model -> Html Msg
view model =
  Html.div
    []
    ((currentView model) :: (List.map button messages))

currentView : Model -> Html Msg
currentView model =
  Html.div [] [ Html.text ("Current View: " ++ model) ]

button : Msg -> Html Msg
button msg =
  Html.button
    [ Events.onClick msg ]
    [ Html.text (msgToString msg) ]

msgToString : Msg -> String
msgToString msg =
  case msg of
    FileNew -> "File > New"
    FileOpen -> "File > Open"
    FileSave -> "File > Save"
    FilePrint -> "File > Print"
    FileQuit -> "File > Quit"
    EditUndo -> "Edit > Undo"
    EditRedo -> "Edit > Redo"
    EditCopy -> "Edit > Copy"
    EditCut -> "Edit > Cut"
    EditPaste -> "Edit > Paste"

messages : List Msg
messages =
  [ FileNew
  , FileOpen
  , FileSave
  , FilePrint
  , FileQuit
  , EditUndo
  , EditRedo
  , EditCopy
  , EditCut
  , EditPaste
  ]

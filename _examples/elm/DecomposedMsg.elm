---
---
import Browser
import Html exposing (Html)
import Html.Events as Events

type alias Model = String

type Msg = File FileMsg | Edit EditMsg

type FileMsg
  = New
  | Open
  | Save
  | Print
  | Quit

type EditMsg
  = Undo
  | Redo
  | Copy
  | Cut
  | Paste

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
    File fileMsg -> "File > " ++ fileMsgToString fileMsg
    Edit editMsg -> "Edit > " ++ editMsgToString editMsg

fileMsgToString : FileMsg -> String
fileMsgToString fileMsg =
  case fileMsg of
    New -> "New"
    Open -> "Open"
    Save -> "Save"
    Print -> "Print"
    Quit -> "Quit"

editMsgToString : EditMsg -> String
editMsgToString editMsg =
  case editMsg of
    Undo -> "Undo"
    Redo -> "Redo"
    Copy -> "Copy"
    Cut -> "Cut"
    Paste -> "Paste"

messages : List Msg
messages =
  [ File New
  , File Open
  , File Save
  , File Print
  , File Quit
  , Edit Undo
  , Edit Redo
  , Edit Copy
  , Edit Cut
  , Edit Paste
  ]

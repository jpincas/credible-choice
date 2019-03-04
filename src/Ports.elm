port module Ports exposing
    ( clipboardSet
    , getChoices
    , putCurrentChoices
    , restoreChoices
    , setClipboard
    )

import Json.Encode as Encode


port putCurrentChoices : Encode.Value -> Cmd msg


port restoreChoices : () -> Cmd msg


port getChoices : (Maybe Encode.Value -> msg) -> Sub msg


port setClipboard : Encode.Value -> Cmd msg


port clipboardSet : (Encode.Value -> msg) -> Sub msg

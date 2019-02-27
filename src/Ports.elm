port module Ports exposing
    ( getChoices
    , putCurrentChoices
    , restoreChoices
    )

import Json.Encode as Encode


port putCurrentChoices : Encode.Value -> Cmd msg


port restoreChoices : () -> Cmd msg


port getChoices : (Maybe Encode.Value -> msg) -> Sub msg

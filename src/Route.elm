module Route exposing
    ( Route(..)
    , homeRoute
    , href
    , parse
    , unparse
    )

import Html
import Html.Attributes
import Url
import Url.Parser as Parser exposing ((</>), Parser)


type Route
    = Choose
    | Authenticate
    | Donate
    | NotFound


homeRoute : Route
homeRoute =
    Choose


parse : Url.Url -> Route
parse url =
    let
        routeParser : Parser (Route -> a) a
        routeParser =
            Parser.oneOf
                [ Parser.map homeRoute Parser.top
                , Parser.map Choose <| Parser.s "choose"
                , Parser.map Authenticate <| Parser.s "auth"
                , Parser.map Donate <| Parser.s "donate"
                ]
    in
    Maybe.withDefault NotFound <|
        Parser.parse routeParser url


href : Route -> Html.Attribute msg
href =
    Html.Attributes.href << unparse


unparse : Route -> String
unparse route =
    let
        parts =
            case route of
                Choose ->
                    [ "choose" ]

                Authenticate ->
                    [ "auth" ]

                Donate ->
                    [ "donate" ]

                NotFound ->
                    [ "notfound" ]
    in
    String.join "/" parts

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
    = ChoosePage
    | TermsAndConditionsPage
    | FaqPage
    | CompanyInfoPage
    | TechnicalInfoPage
    | NotFoundPage


homeRoute : Route
homeRoute =
    ChoosePage


parse : Url.Url -> Route
parse url =
    let
        routeParser : Parser (Route -> a) a
        routeParser =
            Parser.oneOf
                [ Parser.map homeRoute Parser.top
                , Parser.map ChoosePage <| Parser.s "choose"
                , Parser.map TermsAndConditionsPage <| Parser.s "terms"
                , Parser.map FaqPage <| Parser.s "faq"
                , Parser.map CompanyInfoPage <| Parser.s "company"
                , Parser.map TechnicalInfoPage <| Parser.s "technical"
                ]
    in
    Maybe.withDefault NotFoundPage <|
        Parser.parse routeParser url


href : Route -> Html.Attribute msg
href =
    Html.Attributes.href << unparse


unparse : Route -> String
unparse route =
    let
        parts =
            case route of
                ChoosePage ->
                    [ "choose" ]

                TermsAndConditionsPage ->
                    [ "terms " ]

                FaqPage ->
                    [ "faq" ]

                CompanyInfoPage ->
                    [ "company" ]

                TechnicalInfoPage ->
                    [ "technical" ]

                NotFoundPage ->
                    [ "notfound" ]
    in
    String.join "/" parts

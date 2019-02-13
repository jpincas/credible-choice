module Main exposing (main)

import Browser
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav
import FormatNumber
import FormatNumber.Locales
import Html exposing (Attribute, Html, div, text)
import Html.Attributes as Attributes
import Route exposing (Route(..))
import Url


main : Program ProgramFlags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


subscriptions : Model -> Sub Msg
subscriptions =
    always Sub.none


type alias ProgramFlags =
    ()


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , route : Route
    }


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url


init : ProgramFlags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init () url key =
    let
        route =
            Route.parse url

        initialModel =
            { key = key
            , url = url
            , route = route
            }
    in
    noCommand initialModel


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            let
                command =
                    case urlRequest of
                        Browser.Internal url ->
                            Nav.pushUrl model.key <| Url.toString url

                        Browser.External href ->
                            Nav.load href
            in
            ( model, command )

        UrlChanged url ->
            let
                newRoute =
                    Route.parse url
            in
            noCommand { model | url = url, route = newRoute }


withCommands : model -> List (Cmd msg) -> ( model, Cmd msg )
withCommands model commands =
    ( model, Cmd.batch commands )


noCommand : model -> ( model, Cmd msg )
noCommand model =
    ( model, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    let
        contents =
            case model.route of
                Choose ->
                    viewChoose

                Authenticate ->
                    viewAuthenticate

                Donate ->
                    viewDonate

                NotFound ->
                    viewNotFound

        header =
            Html.header
                []
                [ div
                    [ Attributes.id "presentation" ]
                    [ div
                        [ Attributes.id "brexit"
                        , Attributes.class "bold"
                        ]
                        [ text "Brexit" ]
                    , div
                        [ Attributes.id "slogan" ]
                        [ text "Make your voice heard right now" ]
                    ]
                ]

        navigation =
            let
                navItem route =
                    let
                        activeClass =
                            case route == model.route of
                                True ->
                                    "active"

                                False ->
                                    "inactive"
                    in
                    Html.li
                        [ Attributes.class activeClass ]
                        [ Html.a
                            [ Route.href route ]
                            [ text <| routeTitle route ]
                        ]
            in
            Html.nav
                []
                [ Html.ul
                    []
                    (List.map navItem [ Choose, Authenticate, Donate ])
                ]

        footer =
            Html.footer
                []
                [ div
                    [ Attributes.id "logo" ]
                    [ text "Credible Choice" ]
                , div
                    []
                    [ text """Credible choice is a not-for-profit entity that doesn't pay for for services, expenses or salaries. It has
            no income or costs. The companies and individuals that have made a significant contribution are:"""
                    ]
                , Html.ul
                    []
                    [ Html.li
                        []
                        [ text "XXX (identity authentication services)" ]
                    , Html.li
                        []
                        [ text "XXX (website development)" ]
                    , Html.li
                        []
                        [ text "PMPR (public relations)" ]
                    ]
                ]

        body =
            [ header
            , navigation
            , contents
            , footer
            ]

        routeTitle route =
            case route of
                Choose ->
                    "Choose"

                Authenticate ->
                    "Register / Login"

                Donate ->
                    "Donate to Charity"

                NotFound ->
                    "404"
    in
    { title = "Credible Choice - " ++ routeTitle model.route
    , body = body
    }


paragraph : String -> Html msg
paragraph content =
    Html.p [] [ text content ]


viewChoose : Html msg
viewChoose =
    let
        selectedClass b =
            case b of
                True ->
                    Attributes.class "selected"

                False ->
                    Attributes.class "not-selected"

        makeChoice selected chosenBy textContent =
            div
                [ Attributes.class "option button"
                , selectedClass selected
                ]
                [ text textContent
                , div
                    [ Attributes.class "chosen-by" ]
                    [ text "Chosen so far by "
                    , Html.span
                        [ Attributes.class "bold" ]
                        [ text <| formatInt chosenBy ]
                    ]
                ]

        makeRepChoice selected person profession votes =
            Html.tr
                []
                [ Html.td
                    [ Attributes.class "button"
                    , selectedClass selected
                    ]
                    [ text person ]
                , Html.td
                    []
                    [ text profession ]
                , Html.td
                    []
                    [ text <| formatInt votes ]
                ]
    in
    div
        [ Attributes.class "panels" ]
        [ div
            [ Attributes.class "panel" ]
            [ Html.section
                []
                [ Html.h2
                    []
                    [ text "Your Choice Today" ]
                , Html.form
                    [ Attributes.class "choices" ]
                    [ makeChoice True
                        210956
                        "We should accept whatever Theresa May is able to agree with the EU"
                    , makeChoice False
                        123
                        "We should have a decisive break with the EU an envisaged by Jacob Rees Mogg"
                    , makeChoice False
                        20123023
                        "We should stay in the EU on the current basis"
                    ]
                ]
            , div
                [ Attributes.id "total-choices" ]
                [ text "Total choices made so far: 676,879" ]
            , Html.section
                [ Attributes.id "explanation"
                , Attributes.class "explainer"
                ]
                [ paragraph "You can change your mind as many times as you like but only once an hour."
                , Html.p
                    []
                    [ text "Time to next ability to change "
                    , Html.b
                        []
                        [ text <| formatInt 16 ]
                    , text " minutes"
                    ]
                ]
            ]
        , div [ Attributes.class "sep" ] []
        , div
            [ Attributes.class "panel" ]
            [ Html.section
                []
                [ Html.h2
                    []
                    [ text "Who would you choose to represent your views?" ]
                , paragraph "Optionally you can select a person who would represent your views to parliament and the government"
                , Html.table
                    [ Attributes.id "list-of-persons" ]
                    [ Html.thead
                        []
                        [ Html.tr
                            []
                            [ Html.th [] [ text "Person" ]
                            , Html.th [] [ text "Profession" ]
                            , Html.th [] [ text "Choices" ]
                            ]
                        ]
                    , Html.tbody
                        []
                        [ makeRepChoice True "JK Rowling" "Writer" 457365
                        , makeRepChoice False "Katie Hopkins" "Writer" 457365
                        , makeRepChoice False "Piers Morgan" "Writer" 457365
                        , makeRepChoice False "Gary Linekar" "Sports Personality" 457365
                        , makeRepChoice False "Jacob Rees Mogg" "Politician" 457365
                        , makeRepChoice False "Lawrence Dallaglio" "Sports Personality" 457365
                        , makeRepChoice False "Ben Ainslie" "Writer" 457365
                        , makeRepChoice False "Elton John" "Musician" 457365
                        , makeRepChoice False "Billy Brag" "Writer" 457365
                        , makeRepChoice False "Jarvis Cocker" "Musician" 457365
                        , makeRepChoice False "Simon Cowell" "Businessman" 457365
                        , makeRepChoice False "Bob Geldof" "Activist" 457365
                        , makeRepChoice False "Paloma Faith" "Musician" 457365
                        , makeRepChoice False "Patrick Stewart" "Actor" 457365
                        , makeRepChoice False "Daniel Craig" "Actor" 457365
                        , makeRepChoice False "Idris Elba" "Actor" 457365
                        , makeRepChoice False "Helena Bonham Carter" "Actress" 457365
                        , makeRepChoice False "Markus Brigstocke" "Writer" 457365
                        , makeRepChoice False "Stewart Lee" "Writer" 457365
                        , makeRepChoice False "Frankie Boyle" "Writer" 457365
                        , makeRepChoice False "Danny Boyle" "Film director" 457365
                        , makeRepChoice False "Jack Munro" "Writer" 457365
                        , makeRepChoice False "Russell Brand" "Presenter" 457365
                        , makeRepChoice False "Nigel Farage" "Politician" 457365
                        ]
                    ]
                , Html.p
                    []
                    [ text "Showing top "
                    , Html.span
                        [ Attributes.class "bold" ]
                        [ text "25" ]
                    , text " of "
                    , Html.span
                        [ Attributes.class "bold" ]
                        [ text "1,345" ]
                    ]
                , Html.input
                    [ Attributes.type_ "text"
                    , Attributes.placeholder "Search for person"
                    ]
                    []

                -- TODO: Well obviously this is wrong
                , Html.a
                    [ Attributes.class "button"
                    , Route.href Donate
                    ]
                    [ text "Search" ]
                ]
            , Html.section
                [ Attributes.id "add-person" ]
                [ Html.input
                    [ Attributes.type_ "text"
                    , Attributes.placeholder "New person"
                    ]
                    []
                , Html.button
                    [ Attributes.class "button"
                    , Route.href Donate
                    ]
                    [ text "Add" ]
                , paragraph """Any UK citizen with a Wikipedia entry. Confirmation may not be immediate.
                    There is no guarantee that Parliament will take any notice but if someone is chosen by a million people they should be heard.
                    If you appear on this list and you'd rather not, please contact us at
                    remove-me@crediblechoice.co.uk."""
                ]
            ]
        ]


viewAuthenticate : Html msg
viewAuthenticate =
    div
        []
        [ Html.section
            [ Attributes.id "id-verification" ]
            [ Html.h2
                []
                [ text "Identity Verification" ]
            , paragraph """This is to make sure one person expresses one choice, although you can change your mind. We check your
                identity but do not store any personal information about you. Any UK citizen over the age of 17 or person
                with a UK NI number can make a choice."""
            ]
        , Html.section
            [ Attributes.id "existing-users" ]
            [ Html.h3
                []
                [ text "Existing Users" ]
            , div
                []
                [ Html.input
                    [ Attributes.type_ "text"
                    , Attributes.placeholder "UK Mobile Number"
                    ]
                    []
                , Html.a
                    [ Attributes.class "button"
                    , Route.href Route.homeRoute
                    ]
                    [ text "Get Auth Code By SMS" ]
                ]
            ]
        , Html.section
            [ Attributes.id "register" ]
            [ Html.h3
                []
                [ text "New Users" ]
            , Html.input [ Attributes.type_ "text", Attributes.placeholder "First Name" ] []
            , Html.input [ Attributes.type_ "text", Attributes.placeholder "Last Name" ] []
            , Html.input [ Attributes.type_ "text", Attributes.placeholder "Date of birth" ] []
            , Html.input [ Attributes.type_ "text", Attributes.placeholder "Post Code" ] []
            , div
                [ Attributes.class "security-questions" ]
                [ paragraph "ID verification questions"
                , Html.input [ Attributes.type_ "text", Attributes.placeholder "What was the ...............?" ] []
                , Html.input [ Attributes.type_ "text", Attributes.placeholder "When was the ...............?" ] []
                ]
            , Html.input [ Attributes.type_ "text", Attributes.placeholder "UK Mobile Number" ] []
            , Html.a
                [ Attributes.class "button"
                , Route.href Route.homeRoute
                ]
                [ text "Get Auth Code By SMS" ]
            ]
        ]


viewDonate : Html msg
viewDonate =
    Html.section
        []
        [ Html.h2
            []
            [ text "Charitable Sponsorship" ]
        , paragraph """This is entirely optional but you may choose to make a contribution to the following charities by committing
            to donate a certain amount for each 10,000 choices that are made prior to the end of March 2019."""
        , div
            [ Attributes.id "donation-options" ]
            [ Html.input [ Attributes.type_ "text", Attributes.placeholder "£ per 10,000 choices, e.g. £0.01" ] []
            , div
                []
                [ text "Current number of choices: "
                , Html.span
                    [ Attributes.class "bold" ]
                    [ text <| formatInt 676879 ]
                ]
            , div
                []
                [ text "At the current number of choices, your donation would be : "
                , Html.span
                    [ Attributes.class "bold" ]
                    [ text "£"
                    , text "4.75"
                    ]
                ]
            , Html.button
                [ Attributes.class "button" ]
                [ text "Donate" ]
            ]
        , div
            [ Attributes.id "total-choices" ]
            [ text "Total amount committed so far: "
            , text "£1,676,869"
            ]
        ]


viewNotFound : Html msg
viewNotFound =
    text "I am the 404 page."


formatNumberLocale : FormatNumber.Locales.Locale
formatNumberLocale =
    { decimals = 2
    , thousandSeparator = ","
    , decimalSeparator = "."
    , negativePrefix = "−"
    , negativeSuffix = ""
    , positivePrefix = ""
    , positiveSuffix = ""
    }


formatInt : Int -> String
formatInt i =
    let
        locale =
            { formatNumberLocale | decimals = 0 }
    in
    FormatNumber.format locale (toFloat i)

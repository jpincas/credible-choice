module Main exposing (main)

import Array exposing (Array)
import Browser
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav
import Color exposing (Color)
import FormatNumber
import FormatNumber.Locales
import Html exposing (Attribute, Html, div, text)
import Html.Attributes as Attributes
import Html.Events as Events
import Http
import Json.Decode as Decode
import Json.Decode.Pipeline as Pipeline
import Path
import Route exposing (Route(..))
import Shape
import TypedSvg
import TypedSvg.Attributes as SvgAttributes
import TypedSvg.Core
import TypedSvg.Types as SvgTypes
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
    , mainOptions : List MainOption
    , selectedMainOption : Maybe MainOptionId
    , people : List Person
    , selectedRepresentative : Maybe PersonName
    , searchRepresentativeInput : String
    }


type alias MainOptionId =
    String


type alias MainOption =
    { id : MainOptionId
    , name : String
    , description : String
    , votes : Int
    }


type alias PersonName =
    String


type alias Person =
    { name : PersonName
    , position : String
    , votes : Int
    }


type alias HttpResult a =
    Result Http.Error a


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | MainOptionSelected MainOptionId
    | ResultsReceived (HttpResult (List MainOption))
    | PeopleReceived (HttpResult (List Person))
    | SelectRepresentative PersonName
    | SearchRepresentativeInput String


getResults : Cmd Msg
getResults =
    let
        url =
            "http://localhost:5001/appapi/results"

        expect =
            Http.expectJson ResultsReceived resultsDecoder

        resultsDecoder =
            Decode.list mainOptionDecoder

        mainOptionDecoder =
            Decode.succeed MainOption
                |> Pipeline.required "id" Decode.string
                |> Pipeline.required "name" Decode.string
                |> Pipeline.required "description" Decode.string
                |> Pipeline.required "votes" Decode.int
    in
    Http.get { url = url, expect = expect }


getPeople : Cmd Msg
getPeople =
    let
        url =
            "/static/data/people.json"

        expect =
            Http.expectJson PeopleReceived peopleDecoder

        peopleDecoder =
            Decode.list personDecoder

        personDecoder =
            Decode.succeed Person
                |> Pipeline.required "Representative" Decode.string
                |> Pipeline.required "Profession" Decode.string
                |> Pipeline.required "ChosenBy" Decode.int
    in
    Http.get { url = url, expect = expect }


init : ProgramFlags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init () url key =
    let
        route =
            Route.parse url

        initialModel =
            { key = key
            , url = url
            , route = route
            , mainOptions = mainOptions
            , selectedMainOption = Nothing
            , people = []
            , selectedRepresentative = Nothing
            , searchRepresentativeInput = ""
            }

        -- Ultimately we may download these, or include them in the index.html and hence the program flags.
        mainOptions =
            [ { id = "A"
              , name = "May agree"
              , description = "We should accept whatever Theresa May is able to agree with the EU"
              , votes = 100000
              }
            , { id = "B"
              , name = "Decisive break"
              , description = "We should have a decisive break with the EU as envisaged by Jacob Rees Mogg"
              , votes = 40000
              }
            , { id = "C"
              , name = "Remain EU"
              , description = "We should stay in the EU on the current basis"
              , votes = 200000
              }
            ]
    in
    withCommands initialModel [ getResults, getPeople ]


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
            withCommands model [ command ]

        UrlChanged url ->
            let
                newRoute =
                    Route.parse url
            in
            noCommand { model | url = url, route = newRoute }

        MainOptionSelected optionId ->
            -- Note we're not updating the votes here, we do that in the view function for now,
            -- but ultimately it will be when receieve a successful response from the server, which
            -- should include the new number of votes.
            noCommand { model | selectedMainOption = Just optionId }

        ResultsReceived (Err _) ->
            -- TODO: I guess we should have some kind of re-download button or something.
            noCommand model

        ResultsReceived (Ok mainOptions) ->
            noCommand { model | mainOptions = mainOptions }

        PeopleReceived (Err _) ->
            -- TODO: I guess we should have some kind of re-download button or something.
            noCommand model

        PeopleReceived (Ok people) ->
            noCommand { model | people = people }

        SelectRepresentative name ->
            noCommand { model | selectedRepresentative = Just name }

        SearchRepresentativeInput input ->
            noCommand { model | searchRepresentativeInput = input }


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
                    viewChoose model.mainOptions model.selectedMainOption model.people model.selectedRepresentative model.searchRepresentativeInput

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
                    [ Attributes.id "under-construction" ]
                    [ text "Under construction"
                    , Html.p
                        []
                        [ text "We're still building this site, please check back at the beginning of March." ]
                    ]
                , div
                    [ Attributes.id "presentation" ]
                    [ div
                        [ Attributes.id "brexit"
                        , Attributes.class "bold"
                        ]
                        [ text "Brexit" ]
                    , div
                        [ Attributes.id "slogan" ]
                        [ text "Make your voice heard today" ]
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



-- Probably as well to just accept the model here, this app is going to be *mostly* contained within this page.


viewChoose : List MainOption -> Maybe MainOptionId -> List Person -> Maybe PersonName -> String -> Html Msg
viewChoose bareMainOptions mSelectedMainOptionId representatives mSelectedRepresentative searchRepresentativeInput =
    let
        mainOptions =
            -- This is a small hack to have the number of votes incremented for the selected option
            -- *and* decremented if a different option is selected. In production we'll probably update
            -- the whole list of main options in when we receive a response from the server indicating that
            -- the vote has been successful.
            -- Note that we do it outwith the `mainChoice` function since it *also* has to work for the
            -- display of the total number of votes.
            let
                addOneToSelected option =
                    case mSelectedMainOptionId == Just option.id of
                        False ->
                            option

                        True ->
                            { option | votes = option.votes + 1 }
            in
            List.map addOneToSelected bareMainOptions

        selectedClass b =
            case b of
                True ->
                    Attributes.class "selected"

                False ->
                    Attributes.class "not-selected"

        makeChoice option =
            let
                isSelected =
                    mSelectedMainOptionId == Just option.id
            in
            div
                [ Attributes.class "option button"
                , selectedClass isSelected
                , Events.onClick <| MainOptionSelected option.id
                ]
                [ text option.description
                , div
                    [ Attributes.class "chosen-by" ]
                    [ text "Chosen so far by "
                    , Html.span
                        [ Attributes.class "bold" ]
                        [ text <| formatInt option.votes ]
                    ]
                ]

        makeRepChoice person =
            let
                isSelected =
                    mSelectedRepresentative == Just person.name

                votes =
                    case isSelected of
                        True ->
                            person.votes + 1

                        False ->
                            person.votes
            in
            Html.tr
                []
                [ Html.td
                    [ Attributes.class "button"
                    , selectedClass isSelected
                    , Attributes.class "representative-name"
                    , Events.onClick <| SelectRepresentative person.name
                    ]
                    [ text person.name ]
                , Html.td
                    []
                    [ text person.position ]
                , Html.td
                    []
                    [ text <| formatInt votes ]
                ]

        totalNumVotes =
            List.map .votes mainOptions |> List.sum

        filteredRepresentatives =
            case String.isEmpty searchRepresentativeInput of
                True ->
                    representatives

                False ->
                    let
                        searchString =
                            String.toLower searchRepresentativeInput

                        matches person =
                            String.contains searchString <| String.toLower person.name
                    in
                    List.filter matches representatives

        viewPie =
            let
                pieConfig =
                    { startAngle = 0
                    , endAngle = 2 * pi
                    , padAngle = 0
                    , sortingFn = Basics.compare
                    , valueFn = identity
                    , innerRadius = 0
                    , outerRadius = 100
                    , cornerRadius = 0
                    , padRadius = 0
                    }

                arcs =
                    List.map (toFloat << .votes) mainOptions
                        |> Shape.pie pieConfig

                makeSliceAndLabel arc mainOption =
                    let
                        slice =
                            Path.element
                                (Shape.arc arc)
                                [ SvgAttributes.stroke Color.white
                                , SvgAttributes.class [ mainOption.id ]
                                ]

                        ( labelX, labelY ) =
                            Shape.centroid { arc | innerRadius = radius, outerRadius = radius }

                        label =
                            TypedSvg.text_
                                [ SvgAttributes.transform [ SvgTypes.Translate labelX labelY ]
                                , SvgAttributes.dy (SvgTypes.em 2.0)
                                , SvgAttributes.textAnchor SvgTypes.AnchorMiddle
                                ]
                                [ TypedSvg.Core.text mainOption.name ]
                    in
                    ( slice, label )

                width =
                    500

                height =
                    300

                radius =
                    min width height / 2

                ( slices, labels ) =
                    List.map2 makeSliceAndLabel arcs mainOptions
                        |> List.unzip

                pieImage =
                    TypedSvg.svg
                        [ SvgAttributes.viewBox 0 0 width height ]
                        [ TypedSvg.g
                            [ SvgAttributes.transform [ SvgTypes.Translate (width / 2) (height / 2) ] ]
                            [ TypedSvg.g [] slices
                            , TypedSvg.g [] labels
                            ]
                        ]
            in
            pieImage
    in
    div
        [ Attributes.class "panels" ]
        [ div
            [ Attributes.class "panel" ]
            [ Html.section
                []
                [ Html.h2
                    []
                    [ text "What should we do?" ]
                , Html.form
                    [ Attributes.class "choices" ]
                    (List.map makeChoice mainOptions)
                ]
            , div
                [ Attributes.id "total-choices" ]
                [ text "Total choices made so far: "
                , text <| formatInt totalNumVotes
                ]
            , div
                [ Attributes.class "main-option-pie-container" ]
                [ viewPie ]
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
                    [ text "Who do you trust to represent your views?" ]
                , paragraph "You can select a person who would represent your views to parliament and the government"
                , div
                    [ Attributes.id "list-of-persons-container" ]
                    [ Html.table
                        [ Attributes.id "list-of-persons" ]
                        [ Html.thead
                            []
                            [ Html.tr
                                []
                                [ Html.th
                                    []
                                    [ text "Representative"
                                    , Html.br [] []
                                    , Html.span
                                        [ Attributes.class "help-text" ]
                                        [ text "Click to choose" ]
                                    ]
                                , Html.th [] [ text "Profession" ]
                                , Html.th [] [ text "Chosen by" ]
                                ]
                            ]
                        , Html.tbody
                            []
                            (List.map makeRepChoice filteredRepresentatives)
                        ]
                    ]
                , Html.p
                    []
                    [ text "Showing "
                    , Html.span
                        [ Attributes.class "bold" ]
                        [ List.length filteredRepresentatives |> formatInt |> text ]
                    , case String.isEmpty searchRepresentativeInput of
                        True ->
                            text ""

                        False ->
                            Html.span
                                []
                                [ text " of "
                                , Html.span
                                    [ Attributes.class "bold" ]
                                    [ List.length representatives |> formatInt |> text ]
                                , text " matching "
                                , Html.span
                                    [ Attributes.class "bold" ]
                                    [ text "“"
                                    , text searchRepresentativeInput
                                    , text "”"
                                    ]
                                ]
                    ]
                , Html.input
                    [ Attributes.type_ "text"
                    , Attributes.placeholder "Search for person"
                    , Attributes.value searchRepresentativeInput
                    , Events.onInput SearchRepresentativeInput
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
                , let
                    makeOption profession =
                        Html.option
                            [ Attributes.value profession ]
                            [ text profession ]

                    professions =
                        [ "Politician", "Writer", "Entertainer", "Sports person", "Journalist", "Actor" ]

                    pleaseSelect =
                        Html.option
                            [ Attributes.value "" ]
                            [ text "Please select" ]

                    options =
                        pleaseSelect :: List.map makeOption professions
                  in
                  Html.select [] options
                , Html.button
                    [ Attributes.class "button"
                    , Route.href Donate
                    ]
                    [ text "Add" ]
                , paragraph """You may add any British citizen with a Wikipedia entry to the Representative list. They must be 17 or over and able to express their views.  If they ask to be removed, we will remove them.  We will manually check additions and so name may not be immediately added."""
                , paragraph """There is no obligation whatsoever that anyone on this list should do anything and anyone on the list will be removed at their request by contacting us at remove-me@crediblechoice.co.uk (make it a picture)."""
                , paragraph """It’s entirely up to anyone on the list if they want to take any action or organise themselves in any way but we will provide a secure and private (even from us) communication architecture between the top 25 if they provide us with their contact details."""
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

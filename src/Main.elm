module Main exposing (main)

import Array exposing (Array)
import Browser
import Browser.Dom
import Browser.Events
import Browser.Navigation as Nav
import Color exposing (Color)
import Dict exposing (Dict)
import FormatNumber
import FormatNumber.Locales
import Html exposing (Attribute, Html, div, text)
import Html.Attributes as Attributes
import Html.Events as Events
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Pipeline
import Json.Encode as Encode
import Path
import Random
import Random.Char
import Random.Extra
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
    , selectedRepresentative : Maybe Person
    , searchRepresentativeInput : String
    , nonce : Char
    , charity : Maybe String
    , donation : Maybe Pennies
    }


type alias Pennies =
    Int


type alias MainOptionId =
    String


type alias MainOption =
    { id : MainOptionId
    , class : String
    , name : String
    , description : String
    , votes : Int
    }


type alias PersonName =
    String


type alias Person =
    { name : PersonName
    , code : String
    , position : String
    , votes : Int
    }


type alias HttpResult a =
    Result Http.Error a


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | NonceGenerated Char
    | MainOptionSelected MainOptionId
    | ResultsReceived (HttpResult ResultsPayload)
    | PeopleReceived (HttpResult (List Person))
    | SelectRepresentative Person
    | SearchRepresentativeInput String
    | SelectDonationAmount Pennies
    | PrevoteResponse (HttpResult ())


type alias ResultsPayload =
    { mainVote : Dict String Int
    , repVote : Dict String DonateVote
    , charity : Dict String DonateVote
    }


resultsPayloadDecoder : Decoder ResultsPayload
resultsPayloadDecoder =
    Decode.succeed ResultsPayload
        |> Pipeline.required "MainVote" (Decode.dict Decode.int)
        |> Pipeline.required "RepVote" (Decode.dict donateVoteDecoder)
        |> Pipeline.required "Charity" (Decode.dict donateVoteDecoder)


type alias DonateVote =
    { votes : Int
    , amountDonated : Int
    }


donateVoteDecoder : Decoder DonateVote
donateVoteDecoder =
    Decode.succeed DonateVote
        |> Pipeline.required "chosenBy" Decode.int
        |> Pipeline.required "amountDonated" Decode.int


getResults : Cmd Msg
getResults =
    let
        url =
            "/appapi/results"

        expect =
            Http.expectJson ResultsReceived resultsPayloadDecoder
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
                |> Pipeline.hardcoded "CODE1"
                |> Pipeline.required "Profession" Decode.string
                |> Pipeline.required "ChosenBy" Decode.int
    in
    Http.get { url = url, expect = expect }


sendPreVote : Model -> Cmd Msg
sendPreVote model =
    let
        url =
            "/appapi/prevote"

        representative =
            Maybe.map .code model.selectedRepresentative
                |> Maybe.withDefault ""

        body =
            Http.jsonBody <|
                Encode.object
                    [ ( "nonce", Encode.string <| String.fromChar model.nonce )
                    , ( "choice", Encode.string <| Maybe.withDefault "0" model.selectedMainOption )
                    , ( "representative", Encode.string representative )
                    , ( "charity", Encode.string <| Maybe.withDefault "" model.charity )
                    , ( "donation", Encode.int <| Maybe.withDefault 0 model.donation )
                    ]

        toMsg =
            PrevoteResponse

        decoder =
            Decode.succeed ()
    in
    Http.post
        { url = url
        , body = body
        , expect = Http.expectJson toMsg decoder
        }


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
            , nonce = 'q'
            , charity = Nothing
            , donation = Nothing
            }

        -- Ultimately we may download these, or include them in the index.html and hence the program flags.
        mainOptions =
            [ { id = "1"
              , class = "A"
              , name = "May agree"
              , description = "We should accept whatever Theresa May is able to agree with the EU"
              , votes = 100000
              }
            , { id = "2"
              , class = "B"
              , name = "Decisive break"
              , description = "We should have a decisive break with the EU as envisaged by Jacob Rees Mogg"
              , votes = 40000
              }
            , { id = "3"
              , class = "C"
              , name = "Remain EU"
              , description = "We should stay in the EU on the current basis"
              , votes = 200000
              }
            ]

        numbers =
            Random.Char.char 48 57

        generator =
            Random.Extra.choices Random.Char.lowerCaseLatin [ Random.Char.upperCaseLatin, numbers ]

        initNonce =
            Random.generate NonceGenerated generator
    in
    withCommands initialModel [ getResults, getPeople, initNonce ]


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

        NonceGenerated char ->
            noCommand { model | nonce = char }

        MainOptionSelected optionId ->
            -- Note we're not updating the votes here, we do that in the view function for now,
            -- but ultimately it will be when receieve a successful response from the server, which
            -- should include the new number of votes.
            noCommand { model | selectedMainOption = Just optionId }

        ResultsReceived (Err _) ->
            -- TODO: I guess we should have some kind of re-download button or something.
            noCommand model

        ResultsReceived (Ok results) ->
            let
                updateMainOptionVotes option =
                    case Dict.get option.id results.mainVote of
                        Nothing ->
                            { option | votes = 10 }

                        Just votes ->
                            { option | votes = votes }

                newMainOptions =
                    List.map updateMainOptionVotes model.mainOptions
            in
            noCommand { model | mainOptions = newMainOptions }

        PeopleReceived (Err _) ->
            -- TODO: I guess we should have some kind of re-download button or something.
            noCommand model

        PeopleReceived (Ok people) ->
            noCommand { model | people = people }

        SelectRepresentative person ->
            noCommand { model | selectedRepresentative = Just person }

        SearchRepresentativeInput input ->
            noCommand { model | searchRepresentativeInput = input }

        SelectDonationAmount pennies ->
            let
                newModel =
                    { model | donation = Just pennies }
            in
            withCommands newModel [ sendPreVote newModel ]

        -- Strange but there isn't really anything to do upon receiving the prevote
        -- response, we cannot really take any interesting action or give any interesting
        -- information to the user. In theory we could display a dialog saying that they
        -- could press a button to resend, but I think it won't be needed.
        PrevoteResponse (Err _) ->
            noCommand model

        PrevoteResponse (Ok ()) ->
            noCommand model


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
                    viewChoose model

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


viewChoose : Model -> Html Msg
viewChoose model =
    let
        selectedClass b =
            case b of
                True ->
                    Attributes.class "selected"

                False ->
                    Attributes.class "not-selected"

        makeChoice option =
            let
                isSelected =
                    model.selectedMainOption == Just option.id
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
                    case model.selectedRepresentative of
                        Nothing ->
                            False

                        Just rep ->
                            -- TODO: This only really needs to check the code, but since I've hard coded
                            -- that to all be the same temporarily that would make all the representatives appear
                            -- selected.
                            rep.name == person.name && rep.code == person.code
            in
            Html.tr
                []
                [ Html.td
                    [ Attributes.class "button"
                    , selectedClass isSelected
                    , Attributes.class "representative-name"
                    , Events.onClick <| SelectRepresentative person
                    ]
                    [ text person.name ]
                , Html.td
                    []
                    [ text person.position ]
                , Html.td
                    []
                    [ text <| formatInt person.votes ]
                ]

        totalNumVotes =
            List.map .votes model.mainOptions |> List.sum

        filteredRepresentatives =
            case String.isEmpty model.searchRepresentativeInput of
                True ->
                    model.people

                False ->
                    let
                        searchString =
                            String.toLower model.searchRepresentativeInput

                        matches person =
                            String.contains searchString <| String.toLower person.name
                    in
                    List.filter matches model.people

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
                    List.map (toFloat << .votes) model.mainOptions
                        |> Shape.pie pieConfig

                makeSliceAndLabel arc mainOption =
                    let
                        slice =
                            Path.element
                                (Shape.arc arc)
                                [ SvgAttributes.stroke Color.white
                                , SvgAttributes.class [ mainOption.class ]
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
                    List.map2 makeSliceAndLabel arcs model.mainOptions
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

        textBuilder =
            case model.selectedMainOption of
                Nothing ->
                    text "Make a main choice to vote."

                Just option ->
                    case model.donation of
                        Nothing ->
                            text "You must select a donation amount to vote"

                        Just donationPennies ->
                            let
                                repVote =
                                    case model.selectedRepresentative of
                                        Nothing ->
                                            "XXX"

                                        Just rep ->
                                            rep.code

                                charity =
                                    Maybe.withDefault "" model.charity

                                donation =
                                    String.fromInt donationPennies

                                code =
                                    Html.span
                                        [ Attributes.class "text-code" ]
                                        [ Html.span
                                            [ Attributes.class "text-code-main-choice" ]
                                            [ text option ]
                                        , Html.span
                                            [ Attributes.class "text-code-nonce" ]
                                            [ text <| String.fromChar model.nonce ]
                                        , Html.span
                                            [ Attributes.class "text-code-rep" ]
                                            [ text repVote ]
                                        , Html.span
                                            [ Attributes.class "text-code-charity" ]
                                            [ text charity ]
                                        ]
                            in
                            div
                                [ Attributes.class "text-builder" ]
                                [ text "CHOICE"
                                , text " "
                                , code
                                , text " "
                                , text donation
                                ]

        choicePanel =
            div
                [ Attributes.class "panel" ]
                [ Html.section
                    []
                    [ Html.h2
                        []
                        [ text "What should we do?" ]
                    , Html.form
                        [ Attributes.class "choices" ]
                        (List.map makeChoice model.mainOptions)
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
                , textBuilder
                ]

        representativePanel =
            div
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
                        , case String.isEmpty model.searchRepresentativeInput of
                            True ->
                                text ""

                            False ->
                                Html.span
                                    []
                                    [ text " of "
                                    , Html.span
                                        [ Attributes.class "bold" ]
                                        [ List.length model.people |> formatInt |> text ]
                                    , text " matching "
                                    , Html.span
                                        [ Attributes.class "bold" ]
                                        [ text "“"
                                        , text model.searchRepresentativeInput
                                        , text "”"
                                        ]
                                    ]
                        ]
                    , Html.input
                        [ Attributes.type_ "text"
                        , Attributes.placeholder "Search for person"
                        , Attributes.value model.searchRepresentativeInput
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

        charityPanel =
            div
                [ Attributes.class "panel" ]
                [ Html.section
                    []
                    [ Html.h2
                        []
                        [ text "How much" ]
                    , let
                        makeDonationOption amount =
                            let
                                selected =
                                    model.donation == Just amount
                            in
                            Html.label
                                [ Attributes.class "donation-option-label"
                                , Attributes.class "button"
                                , selectedClass selected
                                ]
                                [ text <| formatPence amount
                                , Html.input
                                    [ Attributes.class "donation-option-input"
                                    , Attributes.type_ "radio"
                                    , Events.onClick <| SelectDonationAmount amount
                                    , Attributes.selected selected
                                    ]
                                    []
                                ]
                      in
                      Html.div
                        [ Attributes.id "donation-amount-selector" ]
                        (List.map makeDonationOption [ 50, 100, 500, 1000, 2000 ])
                    , Html.h2
                        []
                        [ text "To which charity" ]
                    ]
                ]

        panelSeparator =
            div [ Attributes.class "sep" ] []

        panels =
            List.intersperse panelSeparator
                [ choicePanel
                , representativePanel
                , charityPanel
                ]
    in
    div
        [ Attributes.class "panels" ]
        panels


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


formatPence : Pennies -> String
formatPence pennies =
    let
        totalString =
            String.fromInt pennies
                |> String.padLeft 3 '0'

        penceString =
            String.right 2 totalString

        poundsString =
            String.dropRight 2 totalString
    in
    String.join ""
        [ "£"
        , poundsString
        , "."
        , penceString
        ]

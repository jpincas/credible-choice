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
    , postcode : String
    , birthyear : String
    , people : List Person
    , selectedRepresentative : Maybe Person
    , searchRepresentativeInput : String
    , representativePage : Int
    , nonce : Char
    , charity : Maybe CharityId
    , charities : List Charity
    , donation : Maybe Pennies
    }


type alias CharityId =
    String


type alias Charity =
    { id : CharityId
    , name : String
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
    | PostCodeInput String
    | BirthYearInput String
    | ResultsReceived (HttpResult ResultsPayload)
    | PeopleReceived (HttpResult (List Person))
    | SelectRepresentative Person
    | ClearRepresentativeChoice
    | SearchRepresentativeInput String
    | RepPageNext
    | RepPagePrev
    | SelectDonationAmount Pennies
    | PrevoteResponse (HttpResult ())
    | CharitiesReceived (HttpResult (List Charity))
    | MakeCharityChoice CharityId
    | ClearCharityChoice


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


getCharities : Cmd Msg
getCharities =
    let
        url =
            "/appapi/charities"

        expect =
            Http.expectJson CharitiesReceived charitiesDecoder

        charitiesDecoder =
            Decode.keyValuePairs charityDecoder
                |> Decode.map (List.map Tuple.second)

        charityDecoder =
            Decode.succeed Charity
                |> Pipeline.required "id" Decode.string
                |> Pipeline.required "name" Decode.string
    in
    Http.get { url = url, expect = expect }


type alias CodeComponents =
    { nonce : String
    , repVote : String
    , charity : String
    }


codeComponents : Model -> CodeComponents
codeComponents model =
    { nonce = String.fromChar model.nonce
    , repVote =
        case model.selectedRepresentative of
            Nothing ->
                "XXX"

            Just rep ->
                rep.code
    , charity = Maybe.withDefault "" model.charity
    }


viewTextCode : Model -> Html msg
viewTextCode model =
    case model.selectedMainOption of
        Nothing ->
            text "Make a main choice to vote."

        Just option ->
            case model.selectedRepresentative == Nothing of
                True ->
                    text "You must make a representative choice to vote. No representative is an option"

                False ->
                    case model.donation of
                        Nothing ->
                            text "You must select a donation amount to vote"

                        Just donationPennies ->
                            case model.charity == Nothing of
                                True ->
                                    text "You must select a charity to vote."

                                False ->
                                    let
                                        donation =
                                            String.fromInt donationPennies

                                        codeParts =
                                            codeComponents model

                                        code =
                                            Html.span
                                                [ Attributes.class "text-code" ]
                                                [ Html.span
                                                    [ Attributes.class "text-code-main-choice" ]
                                                    [ text option ]
                                                , Html.span
                                                    [ Attributes.class "text-code-nonce" ]
                                                    [ text codeParts.nonce ]
                                                , Html.span
                                                    [ Attributes.class "text-code-rep" ]
                                                    [ text codeParts.repVote ]
                                                , Html.span
                                                    [ Attributes.class "text-code-charity" ]
                                                    [ text codeParts.charity ]
                                                ]
                                    in
                                    div
                                        [ Attributes.class "text-builder" ]
                                        [ text "CCH"
                                        , text " "
                                        , code
                                        , text " "
                                        , text donation
                                        ]


sendPreVote : Model -> Cmd Msg
sendPreVote model =
    let
        url =
            "/appapi/prevote"

        codeParts =
            codeComponents model

        code =
            String.join "" [ codeParts.nonce, codeParts.repVote, codeParts.charity ]

        birthyear =
            case String.toInt model.birthyear of
                Nothing ->
                    ""

                Just i ->
                    case i >= 1900 && i <= 2003 of
                        True ->
                            model.birthyear

                        False ->
                            ""

        body =
            Http.jsonBody <|
                Encode.object
                    [ ( "nonce", Encode.string codeParts.nonce )
                    , ( "choice", Encode.string <| Maybe.withDefault "0" model.selectedMainOption )
                    , ( "representative", Encode.string codeParts.repVote )
                    , ( "charity", Encode.string codeParts.charity )
                    , ( "donation", Encode.int <| Maybe.withDefault 0 model.donation )
                    , ( "coded-part", Encode.string code )
                    , ( "birthyear", Encode.string birthyear )
                    , ( "postcode", Encode.string model.postcode )
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
            , postcode = ""
            , birthyear = ""
            , people = []
            , selectedRepresentative = Nothing
            , representativePage = 0
            , searchRepresentativeInput = ""
            , nonce = 'q'
            , charity = Nothing
            , charities = []
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
    withCommands initialModel [ getResults, getPeople, initNonce, getCharities ]


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

        PostCodeInput input ->
            noCommand { model | postcode = input }

        BirthYearInput input ->
            noCommand { model | birthyear = input }

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

        CharitiesReceived (Err _) ->
            noCommand model

        CharitiesReceived (Ok charities) ->
            noCommand { model | charities = charities }

        MakeCharityChoice charityId ->
            let
                command =
                    sendPreVote model
            in
            withCommands { model | charity = Just charityId } [ command ]

        ClearCharityChoice ->
            noCommand { model | charity = Nothing }

        SelectRepresentative person ->
            noCommand { model | selectedRepresentative = Just person }

        ClearRepresentativeChoice ->
            noCommand { model | selectedRepresentative = Nothing }

        RepPageNext ->
            noCommand { model | representativePage = model.representativePage + 1 }

        RepPagePrev ->
            noCommand { model | representativePage = max 0 <| model.representativePage - 1 }

        SearchRepresentativeInput input ->
            noCommand { model | searchRepresentativeInput = input, representativePage = 0 }

        SelectDonationAmount pennies ->
            noCommand { model | donation = Just pennies }

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
        displayConstruction =
            model.route /= FaqPage && constructionUrl

        constructionUrl =
            String.startsWith "www" model.url.host || String.startsWith "crediblechoice.uk" model.url.host
    in
    case displayConstruction of
        True ->
            viewUnderConstructionPage

        False ->
            viewTemporary model


viewUnderConstructionPage : Browser.Document Msg
viewUnderConstructionPage =
    let
        body =
            div
                [ Attributes.class "under-construction-info" ]
                [ paragraph "We are still under construction."
                , Html.p
                    []
                    [ text "For now you can see "
                    , Html.a
                        [ Route.href FaqPage ]
                        [ text "our FAQ " ]
                    ]
                , Html.p
                    []
                    [ Html.h4
                        []
                        [ text "General enquiries" ]
                    , div
                        []
                        [ text "Email: "
                        , Html.a
                            [ Attributes.href "mailto:info@crediblechoice.uk" ]
                            [ text "info@crediblechoice.uk" ]
                        ]
                    , div
                        []
                        [ text "Phone: 07894 158169" ]
                    ]
                ]

        header =
            viewHeader False
    in
    { title = "Credible Choice - Under Construction"
    , body = [ header, body ]
    }


viewHeader : Bool -> Html Msg
viewHeader showBackButton =
    let
        backButton =
            case showBackButton of
                True ->
                    text ""

                False ->
                    Html.a
                        [ Route.href ChoosePage ]
                        [ text "Back" ]
    in
    Html.header
        []
        [ div
            [ Attributes.id "under-construction" ]
            [ Html.h2 [] [ text "Under construction" ]
            , Html.p
                []
                [ text "This site is in test mode.  It will go live at 01:01 on March 1st 2019 - "
                , Html.a
                    [ Route.href FaqPage ]
                    [ text "See FAQ " ]
                ]
            ]
        , div
            [ Attributes.id "presentation" ]
            [ backButton
            , div
                [ Attributes.id "brexit"
                , Attributes.class "bold"
                ]
                [ text "Brexit" ]
            , div
                [ Attributes.id "slogan" ]
                [ text "Make your voice heard today" ]
            , div
                [ Attributes.id "twitter-link" ]
                []
            ]
        ]


viewTemporary : Model -> Browser.Document Msg
viewTemporary model =
    let
        contents =
            case model.route of
                ChoosePage ->
                    viewChoose model

                TermsAndConditionsPage ->
                    viewTermsAndConditions

                FaqPage ->
                    viewFaqPage

                CompanyInfoPage ->
                    viewCompanyPage

                TechnicalInfoPage ->
                    viewTechnicalPage

                NotFoundPage ->
                    viewNotFound

        header =
            let
                showBackButton =
                    model.route == ChoosePage
            in
            viewHeader showBackButton

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
                    (List.map navItem [ TermsAndConditionsPage, FaqPage, CompanyInfoPage, TechnicalInfoPage ])
                ]

        footer =
            Html.footer
                []
                [ div
                    [ Attributes.id "footer-title" ]
                    [ text "Credible Choice Ltd" ]
                , div
                    [ Attributes.id "footer-about" ]
                    [ text "About" ]
                , navigation
                , div
                    [ Attributes.class "footer-section" ]
                    [ Html.h2
                        [ Attributes.class "footer-section-title" ]
                        [ text "Sponsers and Contributors" ]
                    ]
                , div
                    [ Attributes.id "footer-copyright" ]
                    [ text "Credible Choice Ltd 2019" ]
                ]

        body =
            [ header
            , contents
            , footer
            ]

        routeTitle route =
            case route of
                ChoosePage ->
                    "Choose"

                TermsAndConditionsPage ->
                    "Terms and Conditions "

                FaqPage ->
                    "FAQ"

                CompanyInfoPage ->
                    "Company"

                TechnicalInfoPage ->
                    "Technical"

                NotFoundPage ->
                    "Not found"
    in
    { title = "Credible Choice - " ++ routeTitle model.route
    , body = body
    }


paragraph : String -> Html msg
paragraph content =
    Html.p [] [ text content ]


selectedClass : Bool -> Html.Attribute msg
selectedClass b =
    case b of
        True ->
            Attributes.class "selected"

        False ->
            Attributes.class "not-selected"


viewChoose : Model -> Html Msg
viewChoose model =
    let
        sections =
            [ liveResultsSection model
            , makeYourChoiceIntroduction model
            , makeYourChoiceMain model
            , makeYourChoiceRep model
            , donationSection model
            , smsBuilder model
            ]
    in
    div
        [ Attributes.id "choose-page-sections" ]
        sections


mainSection : String -> List (Html Msg) -> Html Msg
mainSection titleText contents =
    let
        title =
            Html.h2
                [ Attributes.class "main-choice-section-title" ]
                [ text titleText ]
    in
    Html.section
        [ Attributes.class "main-choice-section" ]
        (title :: contents)


totalNumVotes : Model -> Int
totalNumVotes model =
    List.map .votes model.mainOptions |> List.sum


liveResultsSection : Model -> Html Msg
liveResultsSection model =
    let
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

        viewRep i person =
            Html.li
                [ Attributes.class "top-ten-rep" ]
                [ Html.span [ Attributes.class "rep-position" ] [ text <| String.fromInt <| i + 1 ]
                , Html.span [ Attributes.class "rep-name" ] [ text person.name ]
                , Html.span [ Attributes.class "rep-score" ] [ text <| String.fromInt 1500000 ]
                ]

        viewReps =
            div
                [ Attributes.id "live-results-representatives" ]
                [ Html.ul
                    [ Attributes.class "top-ten-representatives" ]
                    (List.indexedMap viewRep <| List.take 10 model.people)
                , div
                    [ Attributes.class "total-votes" ]
                    [ Html.label
                        []
                        [ text "Total number of choices" ]
                    , text <| formatInt <| totalNumVotes model
                    ]
                , div
                    [ Attributes.class "total-charity" ]
                    [ Html.label
                        []
                        [ text "Total raised for charity" ]

                    -- TODO: Obviously we need to get this from somewhere?
                    , text <| formatPence 50
                    ]
                ]
    in
    mainSection "Live Results Summary"
        [ div
            [ Attributes.class "panels" ]
            [ div [ Attributes.class "panel" ] [ viewPie ]
            , div [ Attributes.class "panel" ] [ viewReps ]
            ]
        ]


makeYourChoiceIntroduction : Model -> Html Msg
makeYourChoiceIntroduction model =
    let
        explanation =
            Html.p
                [ Attributes.class "introduction-explanation" ]
                [ text """You need a UK mobile to express a choice and must be willing to donate at least 50p to a listed Charity.
You can change your mind and make a choice as many times as you like from a single mobile.
 Only your latest choice will be shown but your total donation will be recorded.
As you select your choice, you will see a sms build at the bottom of the screen.
Send this text to the short number shown and your choice will shortly appear in the live results.
                 """
                ]

        personalInfoInputs =
            div
                [ Attributes.class "personal-information-inputs" ]
                [ div
                    []
                    [ Html.label
                        [ Attributes.class "post-code-label" ]
                        [ text "Postcode, first 3-4 characters" ]
                    , Html.input
                        [ Attributes.class "post-code-input"
                        , Events.onInput PostCodeInput
                        , Attributes.value model.postcode
                        , Attributes.type_ "text"
                        , Attributes.maxlength 4
                        , Attributes.placeholder "E.g. SW19"
                        ]
                        []
                    ]
                , div
                    []
                    [ Html.label
                        [ Attributes.class "birthyear-label" ]
                        [ text "Year of birth" ]
                    , Html.input
                        [ Attributes.class "birthyear-input"
                        , Events.onInput BirthYearInput
                        , Attributes.value model.birthyear
                        , Attributes.type_ "number"
                        , Attributes.min "1900"
                        , Attributes.max "2003"
                        , Attributes.placeholder "E.g. 1980"
                        ]
                        []
                    ]
                ]
    in
    mainSection "Make your choice - Introduction"
        [ div
            [ Attributes.class "panels" ]
            [ div [ Attributes.class "panel" ] [ explanation ]
            , div
                [ Attributes.class "panel" ]
                [ div
                    [ Attributes.class "optional-label" ]
                    [ text "Information about yourself (optional)" ]
                , personalInfoInputs
                , div
                    [ Attributes.class "presentation-only" ]
                    [ text "Used for presentation only.  We do not collect any personal data, not even your mobile number." ]
                ]
            ]
        ]


makeYourChoiceMain : Model -> Html Msg
makeYourChoiceMain model =
    let
        makeChoice option =
            let
                isSelected =
                    model.selectedMainOption == Just option.id
            in
            div
                [ Attributes.class "main-option-button" ]
                [ Html.button
                    [ Attributes.class "option button"
                    , selectedClass isSelected
                    , Events.onClick <| MainOptionSelected option.id
                    ]
                    [ text option.description
                    , Html.span
                        [ Attributes.class "number-choices" ]
                        [ text <| "Chosen by " ++ formatInt option.votes ]
                    ]
                ]

        totals =
            div
                [ Attributes.class "main-option-totals-row" ]
                [ Html.span [ Attributes.class "total-choices-label" ] [ text "Total choices so far" ]
                , Html.span [ Attributes.class "total-choices-value" ] [ text <| formatInt <| totalNumVotes model ]
                ]

        choices =
            List.map makeChoice model.mainOptions ++ [ totals ]
    in
    mainSection "Make your choice - What should we do?"
        [ div
            [ Attributes.class "panels" ]
            [ div [ Attributes.class "panel" ] choices ]
        ]


clickToChoose : Html msg
clickToChoose =
    Html.span
        [ Attributes.class "help-text" ]
        [ text "Click to choose" ]


makeYourChoiceRep : Model -> Html Msg
makeYourChoiceRep model =
    let
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

                votes =
                    case person.votes == 0 of
                        True ->
                            text ""

                        False ->
                            text <| formatInt person.votes
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
                    [ votes ]
                , Html.td
                    []
                    -- TODO: We need the associated donations from the backend somehow
                    [ text <| "£" ++ String.fromInt 56754 ]
                ]

        people =
            { name = "No represenative"
            , code = "Non"
            , position = ""
            , votes = 0
            }
                :: model.people

        filteredRepresentatives =
            case String.isEmpty model.searchRepresentativeInput of
                True ->
                    people

                False ->
                    let
                        searchString =
                            String.toLower model.searchRepresentativeInput

                        matches person =
                            String.contains searchString <| String.toLower person.name
                    in
                    List.filter matches people

        numFiltered =
            List.length filteredRepresentatives

        selectedRepresentatives =
            case repsPerPage * model.representativePage > numFiltered of
                True ->
                    List.drop (numFiltered - repsPerPage) filteredRepresentatives

                False ->
                    List.drop (repsPerPage * model.representativePage) filteredRepresentatives
                        |> List.take repsPerPage

        repsPerPage =
            25

        pageSelector =
            case List.length filteredRepresentatives > 25 of
                False ->
                    text ""

                True ->
                    let
                        prevButton =
                            let
                                attribute =
                                    case model.representativePage == 0 of
                                        True ->
                                            Attributes.disabled True

                                        False ->
                                            Events.onClick RepPagePrev
                            in
                            Html.button
                                [ Attributes.class "rep-page-prev"
                                , attribute
                                ]
                                [ text "Prev" ]

                        nextButton =
                            let
                                attribute =
                                    case model.representativePage * repsPerPage >= List.length filteredRepresentatives of
                                        True ->
                                            Attributes.disabled True

                                        False ->
                                            Events.onClick RepPageNext
                            in
                            Html.button
                                [ Attributes.class "rep-page-next"
                                , attribute
                                ]
                                [ text "Next" ]
                    in
                    div
                        [ Attributes.class "rep-page-selector" ]
                        [ prevButton
                        , Html.span
                            [ Attributes.class "rep-page-numbers" ]
                            -- TODO: These numbers may not be correct if we're filtering etc.
                            [ text <| String.fromInt <| model.representativePage * repsPerPage
                            , text " - "
                            , text <| String.fromInt <| (model.representativePage + 1) * repsPerPage
                            ]
                        , nextButton
                        ]

        table =
            Html.table
                [ Attributes.id "list-of-persons" ]
                [ Html.thead
                    []
                    [ Html.tr
                        []
                        [ Html.th
                            []
                            [ text "Name"
                            , Html.br [] []
                            , clickToChoose
                            ]
                        , Html.th [] [ text "Chosen by" ]
                        , Html.th [] [ text "Donations" ]
                        ]
                    ]
                , Html.tbody
                    []
                    (List.map makeRepChoice selectedRepresentatives)
                ]

        totalsRow =
            -- Might need to make this a row in the table.
            Html.div
                [ Attributes.class "representatives-totals-row" ]
                [ Html.span
                    [ Attributes.class "representatives-totals-label" ]
                    [ text "Total donated" ]
                , Html.span
                    [ Attributes.class "representatives-totals-value" ]
                    -- TODO: Again we need this from the backend.
                    [ text <| formatPence <| 50 ]
                ]

        title =
            Html.h2
                []
                [ text "Who do you trust to represent your views on Brexit?" ]

        earlyAddExplanation =
            paragraph "You can select a person who would represent your views to parliament and the government"

        displaying =
            Html.p
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

        searchInput =
            Html.input
                [ Attributes.type_ "text"
                , Attributes.class "rep-search"
                , Attributes.placeholder "Search for person"
                , Attributes.value model.searchRepresentativeInput
                , Events.onInput SearchRepresentativeInput
                , Attributes.placeholder "Search"
                ]
                []

        addRepresentative =
            div
                [ Attributes.id "add-person" ]
                [ Html.input
                    [ Attributes.type_ "text"
                    , Attributes.placeholder "Representative name"
                    ]
                    []
                , Html.button
                    [ Attributes.class "button" ]
                    [ text "Add" ]
                ]

        explanations =
            div
                []
                [ paragraph """You may ask to add any British citizen with a Wikipedia entry to the Representative list. They must be 17 or over and be able to express their views. If they ask to be removed, we will remove them. We will manually check additions and so name may not be immediately added."""
                , paragraph """There is no obligation whatsoever that anyone on this list should do anything and anyone on the list will be removed at their request by contacting us at remove-me@crediblechoice.uk."""
                , paragraph """It’s entirely up to anyone on the list if they want to take any action or organise themselves in any way but we will provide a secure and private (even from us) communication architecture between the top 25 if they provide us with their contact details."""
                ]
    in
    mainSection "Make your choice - Who do you trust?"
        [ div
            [ Attributes.class "panels" ]
            [ div
                [ Attributes.class "panel" ]
                [ title
                , earlyAddExplanation
                , searchInput
                , table
                , pageSelector
                , displaying
                , totalsRow
                , addRepresentative
                , explanations
                ]
            ]
        ]


donationSection : Model -> Html Msg
donationSection model =
    let
        explanations =
            div
                [ Attributes.class "donation-explanation" ]
                [ paragraph """Credible Choice does not receive any money whatsoever from your donation.  It goes directly from your mobile provider to the charity distributor. You will be charged your standard connection Fee."""
                , Html.p
                    [ Attributes.class "donation-permission" ]
                    [ text "You need permission of whoever pays the mobile bill to donate." ]
                ]

        makeCharityChoice charity =
            let
                mId =
                    case String.isEmpty charity.id of
                        True ->
                            Nothing

                        False ->
                            Just charity.id
            in
            Html.tr
                [ Attributes.class "charity-choice-list-item" ]
                [ Html.td
                    []
                    [ Html.button
                        [ Attributes.class "charity-choice"
                        , Events.onClick <| MakeCharityChoice charity.id
                        , selectedClass <| model.charity == Just charity.id
                        ]
                        [ text charity.name ]
                    ]
                , Html.td
                    []
                    []
                , Html.td
                    []
                    []
                , Html.td
                    []
                    []
                ]

        allCharitiesChoice =
            Html.tr
                [ Attributes.class "charity-choice-list-item" ]
                [ Html.td
                    []
                    [ Html.button
                        [ Attributes.class "charity-choice"
                        , Events.onClick <| MakeCharityChoice ""
                        , selectedClass <| model.charity == Just ""
                        ]
                        [ text "Spread over all listed charities" ]
                    ]
                , Html.td
                    []
                    []
                , Html.td
                    []
                    []
                , Html.td
                    []
                    []
                ]

        charityChoices =
            -- TODO: If we have the donation amount I can add a 'total donations row'.
            allCharitiesChoice :: List.map makeCharityChoice model.charities

        table =
            Html.table
                [ Attributes.class "charity-choice-table" ]
                [ Html.thead
                    []
                    [ Html.tr
                        []
                        [ Html.th
                            []
                            [ text "Charity name" ]
                        , Html.th
                            []
                            [ text "Number" ]
                        , Html.th
                            []
                            [ text "Link" ]
                        , Html.th
                            []
                            [ text "Total donations" ]
                        ]
                    ]
                , Html.tbody
                    []
                    charityChoices
                ]

        charityLabel =
            Html.label
                [ Attributes.class "charity-choice-label" ]
                [ text "Which charity would you like to donate to" ]

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

        donationSelection =
            div
                [ Attributes.class "donation-selections" ]
                [ Html.label
                    []
                    [ text "How much would you like to donate?" ]
                , Html.div
                    [ Attributes.id "donation-amount-selector" ]
                    (List.map makeDonationOption [ 50, 100, 500, 1000, 2000 ])
                ]
    in
    mainSection "Make a Donation"
        [ div
            [ Attributes.class "panels" ]
            [ div
                [ Attributes.class "panel" ]
                [ explanations
                , donationSelection
                , charityLabel
                , table
                ]
            ]
        ]


validYearInput : String -> Bool
validYearInput birthyear =
    case String.toInt birthyear of
        Nothing ->
            False

        Just i ->
            i >= 1900 && i <= 2003


validPostCodeInput : String -> Bool
validPostCodeInput postcode =
    let
        length =
            String.length postcode
    in
    length <= 4 && length >= 3


smsBuilder : Model -> Html Msg
smsBuilder model =
    div
        [ Attributes.id "sms-builder" ]
        [ viewTextCode model ]


viewTermsAndConditions : Html msg
viewTermsAndConditions =
    let
        item title contents =
            Html.li
                [ Attributes.class "terms-and-conditions-items" ]
                (Html.h3 [ Attributes.class "terms-and-conditions-item-title" ] [ text title ] :: contents)
    in
    Html.ol
        [ Attributes.class "terms-and-conditions-list" ]
        [ item "Application of these Conditions of Use"
            [ paragraph "By accessing or using any part of www.crediblechoice.uk you agree to be bound by the following conditions of use. If you do not wish to be bound by these conditions, you may not access or use www.crediblechoice.uk."
            , paragraph "We may change these conditions at any time without any notice to you. By your continued access and use of www.crediblechoice.uk you agree to be bound by the most current version of the conditions of use. Please check these conditions periodically for any changes that have been made."
            ]
        , item "Copyright"
            [ paragraph "Except where otherwise noted, the content of www.crediblechoice.uk Web pages (including the design, text, graphics and arrangement thereof) and the software used therein, is the property of and is owned and controlled by Credible Choice Ltd (CC) and is the copyright material of CC."
            ]
        , item "No Licence"
            [ paragraph "Except as expressly provided, nothing contained in these conditions or anywhere on www.crediblechoice.uk shall be construed as conferring any licence under any of CC or any third party's intellectual property rights."
            ]
        , item "Disclaimer of Representations and Warranties"
            [ paragraph "www.crediblechoice.uk is provided by CC on an \"as is\" and \"as and when available\" basis to users. You use www.crediblechoice.uk at your own risk."
            , paragraph "Neither CC nor any of its officers, directors, shareholders, employees, affiliates, agents, third-party content providers, sponsors, licensers, or the like, makes any representation or warranty or condition, either express or implied, to you:"
            , Html.ul
                []
                [ Html.li
                    []
                    [ text "That www.crediblechoice.uk will be uninterrupted or error-free" ]
                , Html.li
                    []
                    [ text "That www.crediblechoice.uk or the computer server from which www.crediblechoice.uk is made available, are free of viruses or other harmful components"
                    ]
                , Html.li
                    []
                    [ text "To the accuracy, content, timeliness, completeness, legality, reliability, quality or suitability of any information, advice, content, service, search results, products or merchandise provided through www.crediblechoice.uk CC makes and you receive, no representations, warranties or conditions, express or implied, statutory or otherwise with respect to:"
                    , Html.ol
                        []
                        [ Html.li
                            []
                            [ text "www.crediblechoice.uk, its content, merchandise, services, documents, information, items or materials provided by CC in connection with the use of www.crediblechoice.uk; or"
                            ]
                        , Html.li
                            []
                            [ text "Any goods or services or information received through or advertised on www.crediblechoice.uk or received through links provided on www.crediblechoice.uk, including without limitation no representations, warranties or conditions of merchantability, suitability, fitness for a particular purpose, non-infringement of proprietary rights or otherwise."
                            ]
                        ]
                    ]
                ]
            , paragraph "No oral advice or written information given by CC or its affiliates, or any of its officers, directors, employees, agents, providers, merchants, sponsors, licensers, or the like, will create a representation, a warranty or condition nor should you rely on any such information or advice."
            , paragraph "In jurisdictions that do not allow the exclusion or disclaimer of certain warranties, the above exclusion may not apply to you."
            ]
        , item "Provision of Advice"
            [ paragraph "CC is not an agent for and does not vouch for those persons, companies and other organisations whose goods or services may be displayed or referred to in www.crediblechoice.uk, nor for the availability, suitability or prices of such goods and services nor for the legal entitlement, competences, professional qualifications, trade certifications, or memberships of trade associations of such persons, companies or other organisations."
            , paragraph "CC advises users to satisfy themselves as to the exact type and nature of goods or services being offered or qualifications held by those persons, companies and other organisations whose goods or services may be displayed or referred to in www.crediblechoice.uk."
            ]
        , item "Limitation of Liability"
            [ paragraph "Neither CC nor its associated content-provider organisations seek to limit or exclude liability for death or personal injury arising from their negligence."
            , paragraph "Under no circumstances will CC or any of its officers, directors, shareholders, employees, affiliates, agents, sponsors, licensers, or any other party involved in the creation, production, maintenance or distribution of www.crediblechoice.uk be liable for any direct, indirect, incidental, special or consequential damages (including but not limited to loss of profits, business, anticipated savings, goodwill, use of data or other intangible losses) that result from either:"
            , Html.ul
                []
                [ Html.li
                    []
                    [ text "The use and reliance on www.crediblechoice.uk; or"
                    ]
                , Html.li
                    []
                    [ text "The inability to use www.crediblechoice.uk; or"
                    ]
                , Html.li
                    []
                    [ text "Mistakes, omissions, interruptions, suspension, termination, deletion of files or email, errors, defects, viruses, delays in operation, transmission or service response time, or any failure of performance with respect to www.crediblechoice.uk including without limitation those arising from acts of God, communications failure, theft, destruction or unauthorised access to CC's records, programs or services; or"
                    ]
                , Html.li
                    []
                    [ text "Merchandise, products or services received through or advertised on www.crediblechoice.uk and merchandise, products or services received through or advertised on any links provided on www.crediblechoice.uk; or"
                    ]
                , Html.li
                    []
                    [ text "Information or advice received through or advertised on www.crediblechoice.uk and information or advice received through or advertised on any links provided on www.crediblechoice.uk; or"
                    ]
                , Html.li
                    []
                    [ text "Any information, data, text, messages and other materials that you email, post upload, reproduce, transmit or is otherwise distributed using www.crediblechoice.uk. CC is unable to ensure or guarantee the security of any information transmitted over the Internet. Any information or data which you transmit to or by using CC is done at your own risk and CC shall not be responsible or liable for any damages or injury that may result from transmitting such information."
                    ]
                ]
            , paragraph "If any jurisdiction does not allow the exclusion or limitation of liability for consequential or incidental damages, liability is limited to the fullest extent permitted by law."
            ]
        , item "Miscellaneous"
            [ paragraph "These conditions and any and all documents specifically referenced herein constitute the entire agreement between you and CC with respect to the subject matter hereof. If any provision contained in these conditions is determined by a court of competent jurisdiction to be illegal, invalid or otherwise unenforceable, that provision shall be severed from these conditions and the remaining provisions shall continue in full force and effect."
            ]
        , item "Jurisdiction and Governing Law"
            [ paragraph "These conditions shall be governed by and construed in accordance with the laws of England. CC controls www.crediblechoice.uk from within the country of England. It can, however, be accessed from other places around the world. Although these places may have different laws from those of England, by accessing www.crediblechoice.uk you agree that the laws of England, without regard to rules relating to conflict of laws, will apply to all matters relating to your use of www.crediblechoice.uk. You and CC also agree to submit to the non-exclusive jurisdiction of the English courts, with respect to such matters. Users of www.crediblechoice.uk accessing it from places outside of England acknowledge that they do so voluntarily and are responsible for complying with local laws."
            ]
        ]


viewFaqPage : Html msg
viewFaqPage =
    let
        faq ( question, answer ) =
            Html.li
                []
                [ div
                    [ Attributes.class "faq-question" ]
                    [ text question ]
                , div
                    [ Attributes.class "faq-answer" ]
                    [ text answer ]
                ]

        faqs =
            [ ( "Demo Mode:  What is the basis for the order and quantities?"
              , "These are illustrative only and will be removed for a clean launch."
              )
            , ( "What’s the point?"
              , "When 50 million people liked an egg, we thought maybe we could get a few million to democratically express their views about the current Brexit situation and potentially generate some substantial funds for charity.  We also think there is a chance of a non Party group emerging from this, who could constructively help to heal the societal divisions Brexit has caused."
              )
            , ( "What’s in this for Credible Choice and it’s promoters?"
              , "We have created Credible Choice Ltd, a volunteer, not-for-profit, non-partisan company.  It doesn’t have any income or expenses and doesn’t pay for supplies and services."
              )
            , ( "What’s the difference between this and a referendum?"
              , "This has been created in a couple of weeks at no cost to HMG  A referendum will take six months and cost many millions to organise.  With this, participants can change their mind in response to changing circumstances."
              )
            , ( "Isn’t this just a self-selecting opinion poll?"
              , "Polls interview supposedly representative groups of maybe 1,000 people.  Our approach enables millions to take part."
              )
            , ( "Why mobile phones when anyone can buy a SIM card for a few pounds and children and foreign powers could vote?"
              , "The honest answer is that this is the only practical way to curtail unlimited multiple voting.  Sure their may be some multiple voting but it’s not so easy to buy and register millions of SIM cards to UK mobile phone numbers.  Any large scale spoofer would also have to donate millions to charity.  We realise this doesn’t exactly align with the electoral roll but it could be argued that this is more democratic in terms of the people affected."
              )
            , ( "Aren’t all sorts of nefarious players going to hack into this making it meaningless and maybe stealing loads of personal data?"
              , "First of all we do not collect any personal data, not even mobile phone numbers.  Secondly, we are completely transparent, participants can see their choice tallied as they make it.  The whole process is underpinned by a distributed block chain which is 100% secure.  Please see the technical overview."
              )
            ]
    in
    Html.ul
        [ Attributes.class "faq-list" ]
        (List.map faq faqs)


viewCompanyPage : Html msg
viewCompanyPage =
    text "I am the company info page."


viewTechnicalPage : Html msg
viewTechnicalPage =
    text "I am the technical info page."


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
    case pennies < 100 of
        True ->
            penceString ++ "p"

        False ->
            String.join ""
                [ "£", poundsString ]

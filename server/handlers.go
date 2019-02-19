package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"
)

const (
	WikiUrl        = "https://en.wikipedia.org/w/api.php"
	WikiApiOptions = "?action=query&format=json&prop=&list=search&titles=&srnamespace=&srlimit=10&srprop=wordcount%7Ctimestamp%7Ccategorysnippet&srsearch="
)

// TODO EdS:
type SearchRepresentativeRequest struct {
	SearchPhrase string `json:"searchPhrase"`
}

type CreateRepresentativeRequest struct {
	id int `json:"pageId"`
}

func ListCharities(w http.ResponseWriter, r *http.Request) {
	respond(w, app.Data.Charities)
}

func ListRecentVotes(w http.ResponseWriter, r *http.Request) {
	votes, err := getRecentVotes()
	if err != nil {
		respondWithError(w, errorTypeDatabase, err)
		return
	}

	respond(w, votes)
}

func GetResults(w http.ResponseWriter, r *http.Request) {
	respond(w, app.Results)
}

func RegisterPreVote(w http.ResponseWriter, r *http.Request) {
	respondOK(w)
}

func ReceiveVote(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	var vote Vote

	// buildFromURLParams will only return an error if there is actually
	// something wrong with the params being sent by the gatweay,
	// not if there's some internal issue parsing the data string
	if err := vote.buildFromURLParams(query); err != nil {
		respondWithError(w, errorTypeBadRequest, err)
		return
	}

	// We'll try to save, but if we can't, the most we can do is log it
	// as there's no point reporting that to the gatweay
	if err := vote.save(); err != nil {
		Log(LogModuleHandlers, false, fmt.Sprintf("Error saving vote %v to DB", vote), err)
	}

	respondOK(w)
}

func ListTopRepresentatives(w http.ResponseWriter, r *http.Request) {
	// TODO EdS: Order
	respond(w, app.Data.Representatives)
}

// The request is in the shape: { "searchTerms": "Example Person" }
func SearchRepresentative(w http.ResponseWriter, r *http.Request) {
	// TODO EdS: Validate the request
	var repSearchRequest SearchRepresentativeRequest
	json.NewDecoder(r.Body).Decode(&repSearchRequest)
	trimmedSearchPhrase := strings.TrimSpace(repSearchRequest.SearchPhrase) // TODO EdS: Tidy this
	wikiSearchTerms := strings.Replace(trimmedSearchPhrase, " ", "+", -1)
	wikiApiUrl := WikiUrl + WikiApiOptions + wikiSearchTerms
	wikiResponse, err := http.Get(wikiApiUrl)
	if err != nil {
		fmt.Printf("Failure %s\n", err) // TODO EdS: Deal with error
	}
	data, _ := ioutil.ReadAll(wikiResponse.Body)
	fmt.Println(string(data)) // TODO EdS: Get pertinent info and return
	respond(w, wikiResponse)
}

func CreateRepresentative(w http.ResponseWriter, r *http.Request) {
	// TODO EdS: Validate request
	var repCreateRequest CreateRepresentativeRequest
	json.NewDecoder(r.Body).Decode(&repCreateRequest)
	// TODO EdS: Create a new Representative
	// TODO EdS: Create a unique id for the Rep
	//generateRepId()
	// TODO EdS: Create Response
}

// TODO EdS: Delete endpoint

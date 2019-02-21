package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
)

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
	// TODO EdS: Order or paging on returned Representatives?
	// TODO EdS: Make the response application/json
	respond(w, app.Data.Representatives)
}

// The request is in the shape: { "searchTerms" }
// The response is in the shape: { "results" : [{ "title", "pageId"}]}
func SearchRepresentative(w http.ResponseWriter, r *http.Request) {
	wikiResponse, err := searchWikipedia(r)
	if err != nil {
		respondWithError(w, errorTypeBadRequest, err)
		return
	}

	searchResponse := buildSearchResponse(wikiResponse) // TODO EdS: Error checking

	respond(w, searchResponse)
}

// The request is in the shape { "wikiId": 123}
func CreateRepresentative(w http.ResponseWriter, r *http.Request) {
	var repCreateRequest CreateRepresentativeRequest
	json.NewDecoder(r.Body).Decode(&repCreateRequest)

	if err := validateCreateRepresentativeRequest(repCreateRequest); err != nil {
		respondWithError(w, errorTypeBadRequest, err)
		return
	}

	wikiResponse := fetchRepresentativeFromWikipedia(repCreateRequest)

	var rep Representative
	if err := rep.buildFromWikiResponse(wikiResponse, repCreateRequest.Id); err != nil {
		respondWithError(w, "Incomplete info for representative", err)
		return
	}
	app.Data.Representatives[strconv.Itoa(repCreateRequest.Id)] = rep

	respondCreated(w)
}

// TODO EdS: Delete endpoint

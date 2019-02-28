package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"

	"github.com/go-chi/chi"
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
	b, err := ioutil.ReadAll(r.Body)
	defer r.Body.Close()
	if err != nil {
		respondWithError(w, errorTypeBodyRead, err)
		return
	}

	var p PreVote

	err = json.Unmarshal(b, &p)
	if err != nil {
		respondWithError(w, errorTypeInvalidBody, err)
		return
	}

	// If the prevote is not valid, then there has been an issue with the JSON
	// sent from the app
	if !p.isValid() {
		respondWithError(w, errorTypeInvalidBody, err)
		return
	}

	p.cache()
	respondOK(w)
}

func ReceiveVote(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	var vote Vote

	// buildFromURLParams will only return an error if there is actually
	// something wrong with the params being sent by the gatweay,
	// not if there's some internal issue parsing the data string
	rawDataString, err := vote.buildFromURLParams(query)
	if err != nil {
		Log(LogModuleHandlers, false, "Error building vote from incoming notification", err)
		respondWithError(w, errorTypeBadRequest, err)
		return
	}

	// We'll try to save, but if we can't, the most we can do is log it
	// as there's no point reporting that to the gatweay
	if err := vote.save(rawDataString); err != nil {
		Log(LogModuleHandlers, false, fmt.Sprintf("Error saving vote %v to DB", vote), err)
	}

	respondOK(w)
}

// The response is in the shape:
// {[
//	"AIA": {
//		"id": "AIA",
//		"name": "Armando Iannucci",
//		"profession": "Satirist",
//		"externalId": "01wd3l",
//		"suspended": false
//  }]}
func ListRepresentatives(w http.ResponseWriter, r *http.Request) {
	respond(w, app.Data.Representatives)
}

// The request is in the shape: { "searchPhrase" : "jeremy corbyn"}
// The response is in the shape:
// { "results" :
//  	[{ "title" : "Jeremy Corbyn",
// 		   "pageId" : "025m87",
// 		   "description": "Leader of the Labour Party"
// 	    ]}
// }
func SearchRepresentative(w http.ResponseWriter, r *http.Request) {
	searchResponse, err := searchKGraph(r)
	if err != nil {
		respondWithError(w, errorTypeBadRequest, err)
		return
	}

	response := buildSearchResponse(searchResponse)

	respond(w, response)
}

// The request is in the shape { "pageId": "025m87" }
func CreateRepresentative(w http.ResponseWriter, r *http.Request) {
	var repCreateRequest CreateRepresentativeRequest
	json.NewDecoder(r.Body).Decode(&repCreateRequest)

	if err := validateCreateRepresentativeRequest(repCreateRequest.Id); err != nil {
		respondWithError(w, errorTypeBadRequest, err)
		return
	}

	// TODO EdS: This check can be inefficient, and might not be necessary
	if err := checkRepresentativeExists(repCreateRequest); err != nil {
		respondWithError(w, errorTypeBadRequest, err)
		return
	}

	fetchResponse, err := fetchRepresentativeFromKGraph(repCreateRequest)
	if err != nil {
		respondWithError(w, "error fetching info from knowledge graph", err)
	}

	var rep Representative
	if err := rep.buildFromFetchResponse(fetchResponse, repCreateRequest.Id); err != nil {
		respondWithError(w, "error building response", err)
		return
	}

	respondCreated(w)
}

// The header takes an internal id (i.e. XXX) and sets the suspended flag on that representative
func SuspendRepresentative(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	if err := validateInternalRepresentativeId(id); err != nil {
		respondWithError(w, errorTypeInvalidId, err)
	}

	if !suspendRepresentative(id) {
		respondNotFound(w)
		return
	}

	respondNoContent(w)
}

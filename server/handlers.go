package main

import "net/http"

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

func ReceiveVote(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()
	var vote Vote

	if err := vote.buildFromURLParams(query); err != nil {
		respondWithError(w, errorTypeBadRequest, err)
		return
	}

	if err := vote.save(); err != nil {
		respondWithError(w, errorTypeDatabase, err)
		return
	}

	respondOK(w)
}

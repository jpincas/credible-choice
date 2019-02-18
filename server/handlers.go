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

func ReceiveVote(w http.ResponseWriter, r *http.Request) {
	// This is where we will need to decipher the incoming
	// data from the SMS donation platform

	vote := Vote{
		AnonMobile:     "xxxxx789",
		Postcode:       "SW9",
		Age:            35,
		MainChoice:     1,
		RepChoice:      1,
		CharityChoice:  1,
		DonationAmount: 2000,
	}

	if err := vote.save(); err != nil {
		respondWithError(w, errorTypeDatabase, err)
		return
	}

	respondOK(w)
}

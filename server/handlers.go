package main

import "net/http"

func ListCharities(w http.ResponseWriter, r *http.Request) {
	respond(w, "List of charities")
}

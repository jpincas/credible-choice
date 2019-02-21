package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
)

const (
	WikiUrlBase = "https://en.wikipedia.org/w/api.php"
	// To search Wikipedia
	WikiApiSearch = "?action=query&format=json&list=search&srlimit=10&srprop=&srsearch="
	// To fetch info on a specific wikipedia page id
	WikiApiQueryIdTemp = "?action=query&format=json&pageids="
)

func searchWikipedia(r *http.Request) (WikiSearchResponse, error) {
	var response WikiSearchResponse
	var repSearchRequest SearchRepresentativeRequest
	json.NewDecoder(r.Body).Decode(&repSearchRequest)

	if repSearchRequest.SearchPhrase == "" {
		msg := "No Wikipedia search terms provided"
		err := errors.New(msg)
		Log(LogModuleWiki, false, msg, err)
		return response, err
	}

	trimmedSearchPhrase := strings.TrimSpace(repSearchRequest.SearchPhrase)
	wikiSearchTerms := strings.Replace(trimmedSearchPhrase, " ", "+", -1)
	wikiApiUrl := WikiUrlBase + WikiApiSearch + wikiSearchTerms

	wikiResponse, err := http.Get(wikiApiUrl)
	if err != nil {
		return response, err
	}

	if err := json.NewDecoder(wikiResponse.Body).Decode(&response); err != nil {
		return response, err
	}

	return response, nil
}

func fetchRepresentativeFromWikipedia(r CreateRepresentativeRequest) WikiInfo {
	wikiApiUrl := WikiUrlBase + WikiApiQueryIdTemp + strconv.Itoa(r.Id)

	wikiResponse, err := http.Get(wikiApiUrl)
	if err != nil {
		fmt.Printf("Failure %s\n", err) // TODO EdS: Deal with error
	}

	var response WikiIdResponse
	if err := json.NewDecoder(wikiResponse.Body).Decode(&response); err != nil {
		fmt.Printf("Failure 1 %s\n", err) // TODO EdS: Deal with error
	}

	var wikiPage WikiInfo
	j, _ := json.Marshal(&response.QueryResult.Pages)
	if err := json.NewDecoder(strings.NewReader(string(j))).Decode(&wikiPage); err != nil {
		fmt.Printf("Failure 1 %s\n", err) // TODO EdS: Deal with error
	}

	return wikiPage
}

type WikiSearchResponse struct {
	Query Query `json:"query"`
}

type Query struct {
	Pages []Page `json:"search"`
}

type Page struct {
	//Ns int `json:"ns"`
	Title  string `json:"title"`
	PageId int    `json:"pageid"`
}

type WikiIdResponse struct {
	QueryResult QueryResult `json:"query"` // TODO EdS: Can I merge these structs?
}

type QueryResult struct {
	Pages json.RawMessage `json:"pages"`
}

type WikiInfo map[string]Pge

type Pge struct {
	PageId int `json:"pageid"`
	//Ns int `json:"ns"`
	Title string `json:"title"`
}

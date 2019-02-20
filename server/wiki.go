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
	// TODO EdS: Look at WikiData API for more semantic search possibilities
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

func fetchRepresentativeFromWikipedia(r CreateRepresentativeRequest) WikiIdResponse {
	wikiApiUrl := WikiUrlBase + WikiApiQueryIdTemp + strconv.Itoa(r.Id)

	wikiResponse, err := http.Get(wikiApiUrl)
	if err != nil {
		fmt.Printf("Failure %s\n", err) // TODO EdS: Deal with error
	}

	var response WikiIdResponse
	if err := json.NewDecoder(wikiResponse.Body).Decode(&response); err != nil {
		fmt.Printf("Failure 1 %s\n", err) // TODO EdS: Deal with error
	}

	return response
}

type WikiSearchResponse struct {
	//BatchComplete string `json:"batchcomplete"`
	//Paging Paging `json:"continue"`
	Query Query `json:"query"`
}

//type paging struct {
//	SrOffset int `json:"sroffset"`
//	Continue string `json:"continue"`
//}

type Query struct {
	//SearchInfo Searchinfo `json:"searchinfo"`
	Pages []Page `json:"search"`
}

//type searchinfo struct {
//	TotalHits int `json:"totalhits"`
//}

type Page struct {
	//Ns int `json:"ns"`
	Title  string `json:"title"`
	PageId int    `json:"pageid"`
}

type WikiIdResponse struct {
	//BatchComplete string `json:"batchcomplete"`
	QueryResult QueryResult `json:"query"` // TODO EdS: Merge these structs
}

type QueryResult struct {
	Pages PageNumber `json:"pages"`
}

type PageNumber struct {
	//Test map[string]Value
	Value struct {
		PageId int `json:"pageid"`
		//Ns int `json:"ns"`
		Title string `json:"title"`
	} `json:"434967"` // TODO EdS: Obviously this cannot be fixed to a particular value!
}

package main

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
)

const (
	KGraphUrlBase       = "https://kgsearch.googleapis.com/v1/entities:search?"
	KGraphApiSearchBase = "languages=en&limit=10" +
		"&types=Person&key="
	KGraphApiKey  = "{placeholder}" // TODO EdS: Temporarily removed - add to env variable
	KGraphSearch  = "&query="
	KGraphFetchId = "&ids="
)

func searchKGraph(r *http.Request) (KGraphResponse, error) {
	var response KGraphResponse
	var repSearchRequest SearchRepresentativeRequest
	json.NewDecoder(r.Body).Decode(&repSearchRequest)

	if repSearchRequest.SearchPhrase == "" {
		msg := "no Knowledge Graph search terms provided"
		err := errors.New(msg)
		Log(LogModuleWiki, false, msg, err)
		return response, err
	}

	trimmedSearchPhrase := strings.TrimSpace(repSearchRequest.SearchPhrase)
	kGraphSearchTerms := strings.Replace(trimmedSearchPhrase, " ", "+", -1)
	kGraphApiUrl := KGraphUrlBase + KGraphApiSearchBase + KGraphApiKey + KGraphSearch + kGraphSearchTerms

	kGraphResponse, err := http.Get(kGraphApiUrl)
	if err != nil {
		return response, err
	}

	if err := json.NewDecoder(kGraphResponse.Body).Decode(&response); err != nil {
		return response, err
	}

	return response, nil
}

func fetchRepresentativeFromKGraph(r CreateRepresentativeRequest) (KGraphResponse, error) {
	var response KGraphResponse
	kGraphApiUrl := KGraphUrlBase + KGraphApiSearchBase + KGraphApiKey + KGraphFetchId + r.Id

	fetchResponse, err := http.Get(kGraphApiUrl)
	if err != nil {
		return response, err
	}

	if err := json.NewDecoder(fetchResponse.Body).Decode(&response); err != nil {
		return response, err
	}

	return response, nil
}

type KGraphResponse struct {
	ItemListElements []KGraphElement `json:"itemListElement"`
}

type KGraphElement struct {
	Person struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		Id          string `json:"@id"`
	} `json:"result"`
}

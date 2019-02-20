package main

import (
	"errors"
)

type Representative struct {
	ID         string `json:"id"`
	FirstName  string `json:"firstName"`
	Surname    string `json:"surname"`
	Profession string `json:"profession"` // TODO EdS: make this optional?
	WikiId     int    `json:"wikiId"`
}

func (r *Representative) buildFromWikiResponse(w WikiIdResponse) error {
	firstName := w.QueryResult.Pages.Value.Title
	wikiId := w.QueryResult.Pages.Value.PageId

	if firstName == "" || wikiId == 0 {
		msg := "Missing information required to build a representative"
		err := errors.New(msg)
		Log(LogModuleRepresentative, false, msg, err)
		return err
	}

	repId, err := generateRepIdFromSingleString(firstName)
	if err != nil {
		Log(LogModuleRepresentative, false, "", err)
		return err
	}

	r.FirstName = firstName
	r.WikiId = wikiId
	r.ID = repId
	// TODO EdS: Set surname
	// TODO EdS: Set Profession

	return nil
}

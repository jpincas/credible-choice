package main

import (
	"errors"
)

var (
	UnexpectedTypeError = errors.New("invalid type")
)

const (
	kGraphId = "kGraphId"
)

type Representative struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Profession string `json:"profession"`
	ExternalId string `json:"externalId"`
	Suspended  bool   `json:"suspended"`
}

func (r *Representative) buildFromFetchResponse(w interface{}, pageId string) error {
	var profession string
	var firstName string

	switch v := w.(type) {
	case KGraphResponse:
		// TODO EdS: Panic here if these fields don't exist
		firstName = v.ItemListElements[0].Person.Name
		profession = v.ItemListElements[0].Person.Description
	case WikiInfo:
		firstName = v[pageId].Title
	default:
		return UnexpectedTypeError
	}

	if firstName == "" {
		err := errors.New("missing information required to build a representative")
		return err
	}

	repId, err := generateRepresentativeId(firstName)
	if err != nil {
		return err
	}

	r.Name = firstName
	r.ExternalId = pageId
	r.ID = repId
	r.Profession = profession
	r.Suspended = false

	app.Data.Representatives[r.ID] = *r
	rewriteRepresentativeCSV()

	return nil
}

func suspendRepresentative(id string) bool {
	rep, ok := app.Data.Representatives[id]
	if !ok {
		return false
	}

	rep.Suspended = true
	app.Data.Representatives[rep.ID] = rep
	app.Data.SuspendedReps[rep.ExternalId] = rep

	rewriteRepresentativeCSV()

	return true
}

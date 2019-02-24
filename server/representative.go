package main

import (
	"errors"
)

var (
	UnexpectedTypeError = errors.New("invalid type")
)

type Representative struct {
	ID         string `json:"id"`
	FirstName  string `json:"firstName"`
	Profession string `json:"profession"`
	ExternalId string `json:"externalId"`
}

func (r *Representative) buildFromFetchResponse(w interface{}, pageId string) error {
	var profession string
	var firstName string

	switch v := w.(type) {
	case KGraphResponse:
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

	r.FirstName = firstName
	r.ExternalId = pageId
	r.ID = repId
	r.Profession = profession

	return nil
}

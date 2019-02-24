package main

import (
	"errors"
)

type SearchRepresentativeRequest struct {
	SearchPhrase string `json:"searchPhrase"`
}

type CreateRepresentativeRequest struct {
	Id string `json:"pageId"`
}

func validateCreateRepresentativeRequest(r CreateRepresentativeRequest) error {
	for _, rep := range app.Data.Representatives {
		if rep.ExternalId == r.Id {
			msg := "A representative already exists with that Wikipedia id"
			err := errors.New(msg)
			return err
		}
	}
	return nil
}

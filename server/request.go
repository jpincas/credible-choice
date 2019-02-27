package main

import (
	"errors"
	"regexp"
)

type SearchRepresentativeRequest struct {
	SearchPhrase string `json:"searchPhrase"`
}

type CreateRepresentativeRequest struct {
	// External id, not the XXX internal id
	Id string `json:"pageId"`
}

func checkRepresentativeExists(r CreateRepresentativeRequest) error {
	for _, rep := range app.Data.Representatives {
		if rep.ExternalId == r.Id {
			msg := "A representative already exists with that external id"
			err := errors.New(msg)
			return err
		}
	}
	return nil
}

func validateCreateRepresentativeRequest(id string) error {
	// Note that this is the external id
	if len(id) < 5 || len(id) > 8 {
		msg := "An invalid external id was used"
		err := errors.New(msg)
		return err
	}
	return nil
}

func validateInternalRepresentativeId(id string) error {
	isUpperAlpha := regexp.MustCompile(`^[A-Z]+$`).MatchString

	if len(id) != 3 || !isUpperAlpha(id) {
		msg := "The internal id of the representative was not valid"
		err := errors.New(msg)
		return err
	}
	return nil
}

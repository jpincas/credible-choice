package main

import (
	"errors"
	"strconv"
)

type SMSTextValues struct {
	MainVote  string `json:"mainVote"`
	RepVote   string `json:"repVote"`
	Charity   string `json:"charity"`
	PostCode  string `json:"postcode"`
	BirthYear uint32 `json:"birthYear"`
}

// A / RBRAN0 / ADA / 1980 / SW16

func (s *SMSTextValues) parse(smsTextString string) error {
	// Check that the string isn't too short
	if len(smsTextString) < 17 {
		return errors.New("SMS text string is too short")
	}

	s.MainVote = string(smsTextString[0])
	s.RepVote = string(smsTextString[1:7])
	s.Charity = string(smsTextString[7:10])

	birthYear, err := strconv.Atoi(string(smsTextString[10:14]))
	if err != nil {
		return errors.New("Birth year is invalid format")
	}
	s.BirthYear = uint32(birthYear)

	s.PostCode = string(smsTextString[14:])

	return nil
}

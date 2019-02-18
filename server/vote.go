package main

import (
	"github.com/jpincas/tormenta"
)

type pence = uint

type Vote struct {
	tormenta.Model

	AnonMobile string `json:"anonMobile"`
	Postcode   string `json:"postcode"`
	Age        uint8  `json:"age"`

	MainChoice     uint8 `json:"mainChoice"`
	RepChoice      uint8 `json:"repChoice"`
	CharityChoice  uint8 `json:"charityChoice"`
	DonationAmount pence `json:"donationAmount"`
}

func (v Vote) save() error {
	_, err := app.DB.Save(&v)
	return err
}

func getRecentVotes() ([]Vote, error) {
	var votes []Vote
	_, err := app.DB.Find(&votes).Reverse().Limit(50).Run()
	return votes, err
}

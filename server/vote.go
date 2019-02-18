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
	// TODO: check mobile before impacting results

	// Note - save and result impacting should really be atomic,
	// but that would be hard to acheive here, so we'll just run a period
	// recalc
	_, err := app.DB.Save(&v)
	if err != nil {
		return err
	}

	v.impactResults()
	return nil
}

func (v Vote) impactResults() {
	// Main choice
	app.Results.MainChoice[v.MainChoice] = app.Results.MainChoice[v.MainChoice] + 1

	// Rep Choice
	app.Results.RepChoice[v.RepChoice] = RepChoiceResult{
		ChosenByCount: app.Results.RepChoice[v.RepChoice].ChosenByCount + 1,
		AmountDonated: app.Results.RepChoice[v.RepChoice].AmountDonated + v.DonationAmount,
	}

	app.Results.Charity[v.CharityChoice] = CharityResult{
		ChosenByCount: app.Results.Charity[v.CharityChoice].ChosenByCount + 1,
		AmountDonated: app.Results.Charity[v.CharityChoice].AmountDonated + v.DonationAmount,
	}
}

func getRecentVotes() ([]Vote, error) {
	var votes []Vote
	_, err := app.DB.Find(&votes).Reverse().Limit(50).Run()
	return votes, err
}

package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"time"

	"github.com/jpincas/tormenta"
)

type pence = uint32

const (
	// URL Paramater names - to be filled in once we have info from the gateway
	smsValueData       = "data"
	smsValueDonation   = "amount"
	smsValueAnonMobile = "phone"
	smsValueShortcode  = "shortcode"
	smsTxIDString      = "transactionid"
)

type Vote struct {
	tormenta.Model

	// Choices
	MainVote uint8  `json:"mainVote"`
	RepVote  string `json:"repVote"`
	Charity  string `json:"charity"`

	// Anonymous data
	AnonMobile string `json:"anonMobile"`
	PostCode   string `json:"postcode"`
	BirthYear  uint16 `json:"birthYear"`
	Donation   pence  `json:"donation"`

	// Gateway meta data
	TransactionID string `json:"-"`
}

func (incomingVote Vote) save(rawDataString string) error {
	// Attempt to load existing vote for this mobile number
	// If there is nothing there, then we just start with a zero struct
	// If there is already a vote there, then we'll work off that as a base
	// and overwrite
	var vote Vote
	n, err := app.DB.First(&vote).Match("anonmobile", incomingVote.AnonMobile).Run()
	if err != nil {
		return err
	}

	// If this person has voted before, start by
	// removing the impact of that vote on the results cache
	if n != 0 {
		vote.subtractFromResults()
	}

	// Set/overwite vote fields
	vote.MainVote = incomingVote.MainVote
	vote.RepVote = incomingVote.RepVote
	vote.Charity = incomingVote.Charity
	vote.AnonMobile = incomingVote.AnonMobile
	vote.PostCode = incomingVote.PostCode
	vote.BirthYear = incomingVote.BirthYear
	vote.Donation = incomingVote.Donation

	// Save (will either create new or update)
	// Note - save and result impacting should really be atomic,
	// but that would be hard to acheive here, so we'll just run a period
	// recalc
	_, err = app.DB.Save(&vote)
	if err != nil {
		return err
	}

	if app.Config.VoteToBlockchain {
		vote.sendToBlockchain(rawDataString)
	}

	// Now (re)impact the results with the final vote
	vote.addToResults()
	return nil
}

func (v Vote) addToResults() {
	// Main choice
	app.Results.MainVote[v.MainVote] = app.Results.MainVote[v.MainVote] + 1

	// Rep Choice
	app.Results.RepVote[v.RepVote] = RepVoteResult{
		ChosenByCount: app.Results.RepVote[v.RepVote].ChosenByCount + 1,
		Donation:      app.Results.RepVote[v.RepVote].Donation + v.Donation,
	}

	app.Results.Charity[v.Charity] = CharityResult{
		ChosenByCount: app.Results.Charity[v.Charity].ChosenByCount + 1,
		Donation:      app.Results.Charity[v.Charity].Donation + v.Donation,
	}
}

func (v Vote) subtractFromResults() {
	// Main choice
	app.Results.MainVote[v.MainVote] = app.Results.MainVote[v.MainVote] - 1

	// Rep Choice
	app.Results.RepVote[v.RepVote] = RepVoteResult{
		ChosenByCount: app.Results.RepVote[v.RepVote].ChosenByCount - 1,
		Donation:      app.Results.RepVote[v.RepVote].Donation - v.Donation,
	}

	app.Results.Charity[v.Charity] = CharityResult{
		ChosenByCount: app.Results.Charity[v.Charity].ChosenByCount - 1,
		Donation:      app.Results.Charity[v.Charity].Donation - v.Donation,
	}
}

func (v *Vote) buildFromURLParams(values url.Values) (string, error) {
	dataString := values.Get(smsValueData)
	donationString := values.Get(smsValueDonation)
	anonMobileString := values.Get(smsValueAnonMobile)
	charityString := values.Get(smsValueShortcode)
	transactionIDString := values.Get(smsTxIDString)

	// We will only return an error under very restricted circumstances
	// that basically mean we can't accept the vote

	// We must have all four values to continue
	if dataString == "" || donationString == "" || anonMobileString == "" || charityString == "" {
		msg := "Missing information in the URL params"
		return "", errors.New(msg)
	}

	// And the donation amount must be valid
	donation, err := strconv.Atoi(donationString)
	if err != nil {
		return "", errors.New("Donation amount is invalid format")
	}

	// Attempt to parse the concatenated data string from the SMS
	// Parsing must be 'succesful' - that's to say, we are going to
	// do our best to decode it, but even if we can't, there's no
	// point in reporting that back up stream
	var smsTextValues SMSTextValues
	smsTextValues.mustParse(dataString)

	// Set the values from SMSTextValues
	// Parsing takes care of setting the defaults if there any issues
	// We do our best to get as much info as possible
	v.MainVote = smsTextValues.MainVote
	v.RepVote = smsTextValues.RepVote

	// If the parsing shows the the sms was 'complete'
	// we'll try to do a lookup for the optional, anonymous data
	if smsTextValues.Complete {
		res, found := app.PreVotes.Get(dataString)
		if found {
			prevote := res.(PreVote)
			v.PostCode = prevote.PostCode
			v.BirthYear = prevote.BirthYear
		}
	}

	// Set the other stuff
	v.AnonMobile = anonMobileString
	v.Donation = uint32(donation)
	v.Charity = charityString
	v.TransactionID = transactionIDString

	return dataString, nil
}

func getRecentVotes() ([]Vote, error) {
	var votes []Vote
	_, err := app.DB.Find(&votes).Reverse().Limit(50).Run()
	return votes, err
}

// sendToBlockchain attempts
func (v Vote) sendToBlockchain(rawDataString string) {
	blockchainVote := BlockchainVoteContainer{
		Vote: BlockchainVote{
			MainVote:  v.MainVote,
			RepVote:   v.RepVote,
			Charity:   v.Charity,
			PostCode:  v.PostCode,
			BirthYear: v.BirthYear,
			Donation:  v.Donation,
		},
		AnonMobile:    v.AnonMobile,
		SMSCode:       rawDataString,
		TransactionID: v.TransactionID,
		VotedAt:       time.Now().UTC(),
	}

	// Marshall blockchain vote to JSON
	jsonStr, err := json.Marshal(blockchainVote)
	if err != nil {
		Log(LogModuleBlockchain, false, "Error marshalling blockchain vote to JSON", err)
	}

	// Send it off
	res, err := http.Post(blockchainURL(blockchainVoteEndpoint), "application/json", bytes.NewBuffer(jsonStr))
	if err != nil {
		Log(LogModuleBlockchain, false, "Error POSTing vote to blockchain", err)
	} else if res.StatusCode != http.StatusOK {
		Log(LogModuleBlockchain, false, fmt.Sprintf("Received non 200 status code (%v) from blockchain", res.StatusCode), nil)
	}
}

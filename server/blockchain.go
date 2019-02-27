package main

import "time"

// Example blockchain vote
// {"vote":{"main_vote":1,"rep_vote":"RBR","charity":"MD","postCode":"SW67","birth_year":1980,"donation":100},"identitifer":"xxx123456xxx","sms_code":"q1RBR","transaction_id":"tx id here","voted_at":"2019-02-21T13:27:20.070566467Z"}

const (
	blockchainVoteEndpoint = "vote"
)

// BlockchainVote represents the vote as the blockchain is expecting it
type BlockchainVoteContainer struct {
	Vote BlockchainVote `json:"vote"`

	AnonMobile    string    `json:"identifier"`
	SMSCode       string    `json:"sms_code"`
	TransactionID string    `json:"transaction_id"`
	VotedAt       time.Time `json:"voted_at"`
}

type BlockchainVote struct {
	MainVote  uint8  `json:"main_vote"`
	RepVote   string `json:"rep_vote"`
	Charity   string `json:"charity"`
	PostCode  string `json:"postCode"`
	BirthYear uint16 `json:"birth_year"`
	Donation  pence  `json:"donation"`
}

func blockchainURL(endpoint string) string {
	return app.Config.BlockchainHost + "/" + endpoint
}

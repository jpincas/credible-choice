package main

import "strconv"

type SMSTextValues struct {
	MainVote uint8  `json:"mainVote"`
	RepVote  string `json:"repVote"`
	Complete bool   `json:"-"`
}

const (
	noVote = uint8(0)
	noRep  = "XXX"
)

// q / 1 / RBR  -> q1RBR

func (s *SMSTextValues) mustParse(smsTextString string) {
	repVote := noRep
	mainVote := noVote

	if len(smsTextString) >= 5 {
		repVote = string(smsTextString[2:5])
		if _, ok := app.Data.Representatives[repVote]; !ok {
			repVote = noRep
		}
		s.Complete = true
	}

	if len(smsTextString) >= 2 {
		mainVoteString := smsTextString[1]

		// If the main vote char can't be decoded, its a no vote
		// If its not valid because its not 1,2,3 its also a no vote
		if i, err := strconv.Atoi(string(mainVoteString)); err != nil {
			mainVote = noVote
		} else if i > 3 {
			mainVote = noVote
		} else {
			mainVote = uint8(i)
		}
	}

	s.MainVote = mainVote
	s.RepVote = repVote
	return
}

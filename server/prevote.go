package main

type PreVote struct {
	SMSString string `json:"smsString"`
	PostCode  string `json:"postcode"`
	BirthYear uint16 `json:"birthYear"`
}

// cache sets the prevote on the prevote cache,
// keyed under the composite sms string,
// and set to default expiry
func (p PreVote) cache() {
	app.PreVotes.Set(p.SMSString, p, 0)
}

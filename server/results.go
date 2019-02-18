package main

type Results struct {
	MainChoice []MainChoiceResult
	RepChoice  []RepChoiceResult
	Charity    []CharityResult
}

type MainChoiceResult struct {
	ChoiceID      uint8 `json:"choiceID"`
	ChosenByCount uint  `json:"chosenBy"`
}

type RepChoiceResult struct {
	ChoiceID      uint8 `json:"choiceID"`
	ChosenByCount uint  `json:"chosenBy"`
	AmountDonated pence `json:"amountDonated"`
}

type CharityResult struct {
	CharityID     uint8 `json:"choiceID"`
	ChosenByCount uint  `json:"chosenBy"`
	AmountDonated pence `json:"amountDonated"`
}

func calcResults() (results Results) {
	results.MainChoice = calcMainChoiceResults()
	results.RepChoice = calcRepChoiceResults()
	results.Charity = calcCharityResults()
	return
}

func calcMainChoiceResults() (results []MainChoiceResult) {
	return
}

func calcRepChoiceResults() (results []RepChoiceResult) {
	return
}

func calcCharityResults() (results []CharityResult) {
	return
}

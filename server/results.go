package main

type Results struct {
	MainChoice map[uint8]uint
	RepChoice  map[uint8]RepChoiceResult
	Charity    map[uint8]CharityResult
}

type RepChoiceResult struct {
	ChosenByCount uint  `json:"chosenBy"`
	AmountDonated pence `json:"amountDonated"`
}

type CharityResult struct {
	ChosenByCount uint  `json:"chosenBy"`
	AmountDonated pence `json:"amountDonated"`
}

func initResults() Results {
	// Initialise all the maps in Results
	// to avoid nil map assignment errors
	return Results{
		MainChoice: map[uint8]uint{},
		RepChoice:  map[uint8]RepChoiceResult{},
		Charity:    map[uint8]CharityResult{},
	}
}

func updateResults() {
	app.Results = calcResults()
}

func calcResults() (results Results) {
	results.MainChoice = calcMainChoiceResults()
	results.RepChoice = calcRepChoiceResults()
	results.Charity = calcCharityResults()
	return
}

func calcMainChoiceResults() map[uint8]uint {
	return map[uint8]uint{}
}

func calcRepChoiceResults() map[uint8]RepChoiceResult {
	return map[uint8]RepChoiceResult{}
}

func calcCharityResults() map[uint8]CharityResult {
	return map[uint8]CharityResult{}
}

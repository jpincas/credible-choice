package main

type Results struct {
	MainVote map[uint8]uint32
	RepVote  map[string]RepVoteResult
	Charity  map[string]CharityResult
}

type RepVoteResult struct {
	ChosenByCount uint32 `json:"chosenBy"`
	Donation      pence  `json:"amountDonated"`
}

type CharityResult struct {
	ChosenByCount uint32 `json:"chosenBy"`
	Donation      pence  `json:"amountDonated"`
}

func initResults() Results {
	// Initialise all the maps in Results
	// to avoid nil map assignment errors
	return Results{
		MainVote: map[uint8]uint32{},
		RepVote:  map[string]RepVoteResult{},
		Charity:  map[string]CharityResult{},
	}
}

func updateResults() {
	app.Results = calcResults()
}

func calcResults() (results Results) {
	results.MainVote = calcMainVoteResults()
	results.RepVote = calcRepVoteResults()
	results.Charity = calcCharityResults()
	return
}

func calcMainVoteResults() map[uint8]uint32 {
	return map[uint8]uint32{}
}

func calcRepVoteResults() map[string]RepVoteResult {
	return map[string]RepVoteResult{}
}

func calcCharityResults() map[string]CharityResult {
	return map[string]CharityResult{}
}

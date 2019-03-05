package main

type Results struct {
	MainVote       map[uint8]uint32
	RepVote        map[string]uint32
	Charity        map[string]uint32
	TotalVotes     uint32
	TotalDonations uint32
}

func initResults() Results {
	// Initialise all the maps in Results
	// to avoid nil map assignment errors
	return Results{
		MainVote:       map[uint8]uint32{},
		RepVote:        map[string]uint32{},
		Charity:        map[string]uint32{},
		TotalVotes:     0,
		TotalDonations: 0,
	}
}

func updateResults() {
	results := initResults()
	var votes []Vote

	// Main vote
	const mainVotesPossible = uint8(3)
	for i := uint8(0); i <= mainVotesPossible; i++ {
		c, err := app.DB.Find(&votes).Match("MainVote", uint8(i)).Count()
		if err != nil {
			Log(LogModuleResults, false, "Error counting main votes", err)
		} else {
			results.MainVote[i] = uint32(c)
		}
	}

	// Rep vote
	for repID := range app.Data.Representatives {
		// First count
		c, err := app.DB.Find(&votes).Match("RepVote", repID).Count()
		if err != nil {
			Log(LogModuleResults, false, "Error counting rep votes", err)
		} else {
			results.RepVote[repID] = uint32(c)
		}
	}

	// Charity choice
	for charityID := range app.Data.Charities {
		// First count
		c, err := app.DB.Find(&votes).Match("Charity", charityID).Count()
		if err != nil {
			Log(LogModuleResults, false, "Error counting charity votes", err)
		} else {
			results.Charity[charityID] = uint32(c)
		}
	}

	// Totals
	var totalDonations uint32
	totalVotes, err := app.DB.Find(&votes).Sum(&totalDonations, "Donation")
	if err != nil {
		Log(LogModuleResults, false, "Error counting total donations", err)
	} else {
		results.TotalVotes = uint32(totalVotes)
		results.TotalDonations = totalDonations
	}

	app.Results = results
	Log(LogModuleResults, true, "Updated results OK", nil)

}

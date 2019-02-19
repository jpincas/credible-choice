package main

import (
	"net/url"
	"testing"
	"time"

	"github.com/patrickmn/go-cache"
)

func Test_BuildVote(t *testing.T) {
	// Needs the app Cache to be set up
	app.PreVotes = cache.New(5*time.Minute, 10*time.Minute)
	// also register a prevote
	PreVote{"q2YORAB", "SW16", 1980}.cache()

	// and someone in the reps map
	app.Data.Representatives = map[string]Representative{
		"YOR": Representative{"YOR", "Yvetta Ortega Ramon"},
	}

	// and charities
	app.Data.Charities = map[string]Charity{
		"AB": Charity{"AB", "A Bright Future"},
	}

	testCases := []struct {
		name         string
		urlValues    url.Values
		expectError  bool
		expectedVote Vote
	}{
		// Actual error producing votes
		{"blank url", url.Values{}, true, Vote{}},
		{"missing phone",
			url.Values{
				smsValueDonation: []string{"50"},
				smsValueData:     []string{"test"},
			}, true, Vote{},
		},
		{"missing data",
			url.Values{
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, true, Vote{},
		},
		{"missing donation",
			url.Values{
				smsValueData:       []string{"test"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, true, Vote{},
		},
		{"all params present - BUT blank data string",
			url.Values{
				smsValueData:       []string{""},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, true, Vote{},
		},

		// All params present, but now we start testing malformations of the sms string
		{"all params present - complete rubbish data string, can't even extract a main vote",
			url.Values{
				smsValueData:       []string{"nothingmeaningful"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   0,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    noRep,
			},
		},
		{"all params present - 1 char sms string",
			url.Values{
				smsValueData:       []string{"n"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   0,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    noRep,
			},
		},
		{"all params present - 2 char sms string, invalid 4",
			url.Values{
				smsValueData:       []string{"n4"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   0,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    noRep,
			},
		},
		{"all params present - 2 char sms string, valid vote",
			url.Values{
				smsValueData:       []string{"n2"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   2,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    noRep,
			},
		},
		{"all params present -  sms string with nonce, vote and no rep",
			url.Values{
				smsValueData:       []string{"n2XXX"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   2,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    noRep,
			},
		},
		{"all params present -  sms string with nonce, vote and rep not present in map",
			url.Values{
				smsValueData:       []string{"n2NOR"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   2,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    noRep,
			},
		},
		{"all params present - sms string with nonce, vote and rep present in map",
			url.Values{
				smsValueData:       []string{"n2YOR"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   2,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    "YOR",
			},
		},
		{"all params present - sms string with nonce, vote, rep present in map, not enough charity chars",
			url.Values{
				smsValueData:       []string{"n2YORA"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   2,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    "YOR",
			},
		},
		{"all params present - sms string with nonce, vote, rep present in map, charity not in map",
			url.Values{
				smsValueData:       []string{"n2YORAA"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   2,
				Charity:    noCharity,
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    "YOR",
			},
		},
		{"all params present - sms string with nonce, vote, rep present in map, charity in map",
			url.Values{
				smsValueData:       []string{"n2YORAB"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   2,
				Charity:    "AB",
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    "YOR",
			},
		},
		{"with prevote - expect the optional data",
			url.Values{
				smsValueData:       []string{"q2YORAB"},
				smsValueDonation:   []string{"50"},
				smsValueAnonMobile: []string{"sdf9s8sd8f6sd"},
			}, false, Vote{
				MainVote:   2,
				Charity:    "AB",
				AnonMobile: "sdf9s8sd8f6sd",
				Donation:   50,
				RepVote:    "YOR",
				PostCode:   "SW16",
				BirthYear:  1980,
			},
		},
	}

	for _, testCase := range testCases {

		urlString := testCase.urlValues.Encode()

		values, err := url.ParseQuery(urlString)
		if err != nil {
			t.Errorf("Testing %s. Failed to even parse url string", testCase.name)
		}

		var vote Vote
		err = vote.buildFromURLParams(values)
		if testCase.expectError && err == nil {
			t.Errorf("Testing %s. Was expecting an error when building vote from URL string, but didn't get one", testCase.name)
		} else if !testCase.expectError && err != nil {
			t.Errorf("Testing %s. Was not expecting an error from buildFromURLParams but got: %v", testCase.name, err)
		} else {
			// Now check all the elements of the vote

			// Main vote
			if testCase.expectedVote.MainVote != vote.MainVote {
				t.Errorf("Testing %s - main vote. Expected vote and actual vote don't match. Expected %v but got %v", testCase.name, testCase.expectedVote.MainVote, vote.MainVote)
			}

			if testCase.expectedVote.RepVote != vote.RepVote {
				t.Errorf("Testing %s - rep vote. Expected vote and actual vote don't match. Expected %v but got %v", testCase.name, testCase.expectedVote.RepVote, vote.RepVote)
			}

			if testCase.expectedVote.Charity != vote.Charity {
				t.Errorf("Testing %s - charity. Expected vote and actual vote don't match. Expected %v but got %v", testCase.name, testCase.expectedVote.Charity, vote.Charity)
			}

			if testCase.expectedVote.AnonMobile != vote.AnonMobile {
				t.Errorf("Testing %s - anon mobile. Expected vote and actual vote don't match. Expected %v but got %v", testCase.name, testCase.expectedVote.AnonMobile, vote.AnonMobile)
			}

			if testCase.expectedVote.Donation != vote.Donation {
				t.Errorf("Testing %s - donation. Expected vote and actual vote don't match. Expected %v but got %v", testCase.name, testCase.expectedVote.Donation, vote.Donation)
			}

			// Optional data

			if testCase.expectedVote.PostCode != vote.PostCode {
				t.Errorf("Testing %s - postcode. Expected vote and actual vote don't match. Expected %v but got %v", testCase.name, testCase.expectedVote.PostCode, vote.PostCode)
			}

			if testCase.expectedVote.BirthYear != vote.BirthYear {
				t.Errorf("Testing %s - birth year. Expected vote and actual vote don't match. Expected %v but got %v", testCase.name, testCase.expectedVote.BirthYear, vote.BirthYear)
			}
		}

	}
}

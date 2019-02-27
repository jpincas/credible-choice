# Credible Choice

## Server

To build and run server and start code-watching 
```
cd server
./watch.sh
```

If you have errors, first
* make sure you have `entr` installed: `sudo apt-get install entr` on linux or Homebrew on Mac, or http://eradman.com/entrproject/) :
* make sure you have `go 1.11` installed
* make sure you have all go dependencies (`./server/deps.sh`)

Once all requirements are resolved, it should run smoothly

Find the api at http://localhost:5001

### Install golang 1.11 on Ubuntu

Since only 1.10 comes by default on Ubuntu 18.04, we need to dig a bit deeper. Luckily there is [a wiki page for it](https://github.com/golang/go/wiki/Ubuntu):

```shell
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-get update
sudo apt-get install golang-go
```

## Client

First, make sure you have elm set up (oh, yeah, and node 10 installed)

`npm install -g elm elm-live`

Then just run:

`./live.sh`

And find the site at http://localhost:6002


## Prevote

This is a sort of 'intention to vote' that is sent to our server by the app.  The sole purpose is to register optional data (postcode / birth year) that will be cross referenced against incoming sms votes.

```golang
type PreVote struct {
	SMSString string `json:"smsString"`
	PostCode  string `json:"postcode"` // first part only, e.g. SW16
	BirthYear uint16 `json:"birthYear"` // e.g. 1980
}
```

## Main Vote

We want to embed the sms message into a concatenated string representing the following data:

```golang
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
}
```

Only the main vote and rep vote are encoded in the SMS.  They are encoded into a string like `q / 1 / RBR -> q1RBR`.  Where `q` is a random nonce drawn from `a-z, A-Z, 0-9`.  

The donation amount needs to be added outside this concatenated string so that the gateway can parse it.

The charity choice is the shortcode set up by the charity with DONR, e.g a charity called 'My Amazing Charity' might have picked `MAC`

The year of birth and postcode are not encoded in the SMS, they are passed to the api in a 'pre-vote'.

Thus, the full text would look like `MAC q1RBR 50`.  This is equivalent to:

```golang
Vote{
    MainVote: 1,
    RepVote: "RBR",
    Charity: "MAC",
    Donation: 50,
    PostCode: "SW16", // from the prevote
    BirthYear: 1980, // from the prevote
}
```

- We are using `XXX` as a no-rep choice


API: all of this information will get posted to the endpoint of our choosing by GET request and with the data encoded in URL parameters.  More info on that to come.

We will provide an encode/decode function from words to vote both in js (for the client) and in go (to write to the db).
We can also provide an online tool to allow people to ensure their code matches their choices.

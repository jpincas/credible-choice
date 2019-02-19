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


## Message Design / SMS Format

We want to embed the sms message into a concatenated string representing the following data:

```golang
type Vote struct {
    MainVote uint8 // 1 digit (1,2,3)
    RepVote string // 3 characters (unique, composed from name and surname)
    Charity string // 2 characters
    PostCode string // 3-4 characters, valid UK post code prefix
    BirthYear uint16 // Hopefully somewhere between 1900 and 2002
    Donation int32  // How many pence were donated
}
```

Only the main vote, rep vote and charity choice are encoded in the SMS.  They are encoded into a string like `q / 1 / RBR / AD  -> q1RBRAD`.  Where `q` is a random nonce drawn from `a-z, A-Z, 0-9`.  

The donation amount needs to be added outside this concatenated string so that the gateway can parse it.  

The year of birth and postcode are not encoded in the SMS, they are passed to the api in a 'pre-vote'.

Thus, the full text would look like `CCH q1RBRAD 50`, where 'CHOICE' is our unique campaign keyword to be assigned by the gateway.  This is equivalent to:

```golang
Vote{
    MainVote: 1,
    RepVote: "RBR",
    Charity: "AD",
    PostCode: "SW16", // from the prevote
    BirthYear: 1980, // from the prevote
    Donation: 50,
}
```

The rep vote is optional - it will default to `NIL`
The charity choice is optional - it will default to `AL`
The year and postcode are both optional - they will not appear at all if not entered.  We will have to be careful with the parser to pick up the right information. Years start with a number and postcodes with a letter, so use that.


API: all of this information will get posted to the endpoint of our choosing by GET request and with the data encoded in URL parameters.  More info on that to come.

We will provide an encode/decode function from words to vote both in js (for the client) and in go (to write to the db).
We can also provide an online tool to allow people to ensure their code matches their choices.

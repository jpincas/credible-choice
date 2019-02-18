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

Find the api at `localhost:5001`.

### Install golang 1.11 on Ubuntu

Since only 1.10 comes by default on Ubuntu 18.04, we need to dig a bit deeper. Luckily there is [a wiki page for it](https://github.com/golang/go/wiki/Ubuntu):

```shell
sudo add-apt-repository ppa:longsleep/golang-backports
sudo apt-get update
sudo apt-get install golang-go
```

## Message Design

We want to embed the sms message into a few human readable words representing the following data:

```golang
type Vote struct {
    MainVote string // 1 character (A B C)
    RepVote string // 4 characters
    Charity string // 3 characters
    PostCode string // 3-4 characters, valid UK post code prefix
    BirthYear int32 // Hopefully somewhere between 1900 and 2002
    Donation int32  // How many pence were donated
}
```

This is encoded into a string like `ABRANADASW161980 50`, which is equivalent to:

```golang
Vote{
    MainVote: "A",
    RepVote: "BRAN",
    Charity: "ADA",
    PostCode: "SW16",
    BirthYear: 1980,
    Donation: 50,
}
```

We will provide an encode/decode function from words to vote both in js (for the client) and in go (to write to the db).
We can also provide an online tool to allow people to ensure their code matches their choices.

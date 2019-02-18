package main

import (
	"io/ioutil"
	"log"
	"net/http"
	"time"
)

const (
	voteEndpoint = "http://localhost:5001/webhooks/vote-fsd8vxcv86vn87s88?data=BRBRAN1ADA1980SW9&amount=100&phone=ddsfs887d98098"
	noRequests   = 1000
)

func main() {
	start := time.Now()

	for i := 0; i < noRequests; i++ {
		resp, err := http.Get(voteEndpoint)
		if err != nil {
			log.Fatalln(err.Error())
		} else if resp.StatusCode != http.StatusOK {
			defer resp.Body.Close()
			body, _ := ioutil.ReadAll(resp.Body)

			log.Fatalln("Error code: ", resp.StatusCode, "Body: ", body)
		}
	}

	elapsed := time.Since(start)
	log.Printf("%v requests took %v", noRequests, elapsed)
}

package main

import (
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"
)

const (
	voteEndpoint = "http://localhost:5001/webhooks/vote-fsd8vxcv86vn87s88?data=BRBRAN1ADA1980SW9&amount=100&phone=ddsfs887d98098"
	noRequests   = 100
)

func main() {

	var wg sync.WaitGroup
	wg.Add(noRequests)

	start := time.Now()

	for i := 0; i < noRequests; i++ {
		go func(ii int) {
			http.Get(fmt.Sprintf("%s%v", voteEndpoint, ii))
			wg.Done()
		}(i)

		// if err != nil {
		// 	log.Fatalln(err.Error())
		// } else if resp.StatusCode != http.StatusOK {
		// 	defer resp.Body.Close()
		// 	body, _ := ioutil.ReadAll(resp.Body)

		// 	log.Fatalln("Error code: ", resp.StatusCode, "Body: ", body)
		// }
	}

	wg.Wait()
	elapsed := time.Since(start)
	log.Printf("%v requests took %v", noRequests, elapsed)
}

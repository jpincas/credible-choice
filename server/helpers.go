package main

import (
	"encoding/json"
	"io/ioutil"
)

// Helpers
//func generateRepId(repName string) id {
//	// TODO EdS: Generate unique id based on name
//}

// Config
func readAndMarshallFile(fileName string, target interface{}) error {
	raw, err := ioutil.ReadFile(fileName)
	if err != nil {
		return err
	}

	if err := json.Unmarshal(raw, target); err != nil {
		return err
	}

	return nil
}

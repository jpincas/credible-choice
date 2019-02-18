package main

import (
	"encoding/json"
	"io/ioutil"
)

// Helpers

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

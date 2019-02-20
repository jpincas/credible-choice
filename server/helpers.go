package main

import (
	"encoding/json"
	"errors"
	"io/ioutil"
	"strings"
)

// Helpers
func generateRepId(firstName string, surname string) (string, error) {
	if firstName == "" {
		err := errors.New("cannot create Representative id from an empty string")
		return "", err
	}

	// TODO EdS: Handle case with no surname

	for i := 1; i < len(surname); i++ {
		var id string = string(firstName[0]) + string(surname[0]) + string(surname[i])
		if _, exists := app.Data.Representatives[id]; !exists {
			return strings.ToUpper(id), nil
		}
	}

	return "", nil
}

// TODO EdS: Delete this when I have first name and surname sorted
func generateRepIdFromSingleString(name string) (string, error) {
	trimmedName := strings.TrimSpace(name)
	names := strings.Split(trimmedName, " ")
	firstName := names[0]
	surname := names[len(names)-1] // TODO EdS: This assumes last part of the name is surname as opposed to position or title

	if firstName == "" {
		err := errors.New("cannot create Representative id from an empty string")
		return "", err
	}

	// TODO EdS: Handle case with no surname

	for i := 0; i < len(firstName); i++ {
		for j := 0; j < len(surname)-1; j++ {
			var id string = string(firstName[i]) + string(surname[j]) + string(surname[j+1])
			if _, exists := app.Data.Representatives[id]; !exists {
				return strings.ToUpper(id), nil
			}
		}
	}

	err := errors.New("") // TODO EdS: Create error properly
	return "", err
}

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

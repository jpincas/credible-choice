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

func generateRepIdFromSingleString(name string) (string, error) {
	trimmedName := strings.TrimSpace(name)
	names := strings.Split(trimmedName, " ")
	firstName := names[0]

	if firstName == "" {
		err := errors.New("cannot create Representative id from an empty string")
		return "", err
	}

	var secondName string
	if len(names) > 1 {
		secondName = names[1]
	} else {
		secondName = names[0][1:] // TODO EdS: What if first name is only 1 character long?
	}

	for i := 0; i < len(firstName); i++ {
		for j := 0; j < len(secondName)-1; j++ {
			var id string = string(firstName[i]) + string(secondName[j]) + string(secondName[j+1])
			if _, exists := app.Data.Representatives[id]; !exists {
				return strings.ToUpper(id), nil
			}
		}
	}

	return "", errors.New("no three letter ID could be created for this Representative")
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

package main

import (
	"encoding/json"
	"errors"
	"io/ioutil"
	"math/rand"
	"strings"
)

// Helpers
func generateRepresentativeId(name string) (string, error) {
	trimmedName := strings.TrimSpace(name)
	names := strings.Split(trimmedName, " ")
	firstName := names[0]

	if firstName == "" {
		err := errors.New("cannot create Representative id without a name")
		return "", err
	}

	var secondName string
	if len(names) > 1 {
		secondName = names[1]
	} else {
		secondName = names[0][1:]
	}

	for i := 0; i < len(firstName); i++ {
		for j := 0; j < len(secondName)-1; j++ {
			var id string = string(firstName[i]) + string(secondName[j]) + string(secondName[j+1])
			if _, exists := app.Data.Representatives[id]; !exists {
				return strings.ToUpper(id), nil
			}
		}
	}

	// If name too short or all relevant namespace taken, randomly generate
	bytes := make([]byte, 3)
	for i := 0; i < 20000; i++ {
		for i := 0; i < 3; i++ {
			bytes[i] = byte(65 + rand.Intn(25))
		}
		id := string(bytes)
		if _, exists := app.Data.Representatives[id]; !exists {
			return id, nil
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

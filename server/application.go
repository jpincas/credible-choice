package main

import (
	"encoding/csv"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"

	"github.com/go-chi/chi"
	"github.com/go-chi/jwtauth"
	"github.com/jpincas/tormenta"
)

// Create an app instance
var app Application

type Application struct {
	Config Config
	Router *chi.Mux
	DB     *tormenta.DB
	Data   Data
}

type Config struct {
	Port          int    `json:"port"`
	TestMode      bool   `json:"testMode"`
	DBDirectory   string `json:"dbDirectory"`
	DataDirectory string `json:"dataDirectory"`
}

type Data struct {
	Charities []Charity
}

func runApplication(configFile string) {
	// Apply App level config
	app.applyConfig(configFile)

	// Initiate the router
	tokenAuth := jwtauth.New("HS256", []byte("secret"), nil)
	app.initRouter(tokenAuth)

	// DB Connection
	var err error
	var db *tormenta.DB
	if app.Config.TestMode {
		db, err = tormenta.OpenTest(app.Config.DBDirectory)
	} else {
		db, err = tormenta.Open(app.Config.DBDirectory)
	}
	if err != nil {
		LogFatal(LogModuleStartup, false, "Error opening DB connection. Aborting", err)
	}
	app.DB = db

	// Read in fixed data
	app.initFixedData()

	// Run the server
	Log(LogModuleStartup, true, fmt.Sprintf("Starting server on port %v", app.Config.Port), nil)
	http.ListenAndServe(fmt.Sprintf(":%v", app.Config.Port), app.Router)
}

func (a *Application) applyConfig(configFileName string) {
	var c Config

	if err := readAndMarshallFile(fmt.Sprintf("%s.json", configFileName), &c); err != nil {
		LogFatal(LogModuleConfig, false, "Error applying APP configuration file. Aborting", err)
	}

	Log(LogModuleConfig, true, "APP config file detected and correctly applied: "+configFileName, nil)
	a.Config = c
}

func (a *Application) initRouter(tokenAuth *jwtauth.JWTAuth) {
	// Initialise a new router
	r := chi.NewRouter()

	// Set up routes
	r.Route("/appapi", func(r chi.Router) {
		r.Get("/charities", ListCharities)
	})

	r.Route("/webhooks", func(r chi.Router) {
	})

	// Log and apply to application
	Log(LogModuleStartup, true, "Router initialised OK", nil)
	a.Router = r
}

func (a Application) close() {
	a.DB.Close()
}

func (a *Application) initFixedData() {
	a.readCharities()
}

func (a *Application) readCharities() error {
	f, err := os.Open(a.Config.DataDirectory + "/charities.csv")
	if err != nil {
		return err
	}
	defer f.Close()

	csvr := csv.NewReader(f)

	charities := []Charity{}
	for {
		record, err := csvr.Read()
		// Stop at EOF.
		if err == io.EOF {
			break
		} else if err != nil {
			return err
		}

		id, err := strconv.Atoi(record[0])
		if err != nil {
			return err
		}
		name := record[1]

		charities = append(charities, Charity{id, name})

	}

	Log(LogModuleStartup, true, "Read in list of charities OK", nil)
	a.Data.Charities = charities
	return nil
}

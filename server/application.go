package main

import (
	"fmt"
	"net/http"

	"github.com/go-chi/chi"
	"github.com/go-chi/jwtauth"
	"github.com/jpincas/tormenta"
)

type Application struct {
	Config Config
	Router *chi.Mux
	DB     *tormenta.DB
}

type Config struct {
	Port          int    `json:"port"`
	TestMode      bool   `json:"testMode"`
	DataDirectory string `json:"dataDirectory"`
}

func run(configFile string) Application {
	// Create an app instance
	var a Application

	// Apply App level config
	a.applyConfig(configFile)

	// Initiate the router
	tokenAuth := jwtauth.New("HS256", []byte("secret"), nil)
	a.initRouter(tokenAuth)

	// DB Connection
	var err error
	var db *tormenta.DB
	if a.Config.TestMode {
		db, err = tormenta.OpenTest(a.Config.DataDirectory)
	} else {
		db, err = tormenta.Open(a.Config.DataDirectory)
	}
	if err != nil {
		LogFatal(LogModuleStartup, false, "Error opening DB connection. Aborting", err)
	}
	a.DB = db

	// Run the server
	Log(LogModuleStartup, true, fmt.Sprintf("Starting server on port %v", a.Config.Port), nil)
	http.ListenAndServe(fmt.Sprintf(":%v", a.Config.Port), a.Router)
	return a
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

package main

import (
	"encoding/csv"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/patrickmn/go-cache"

	"github.com/go-chi/chi"
	"github.com/go-chi/chi/middleware"
	"github.com/go-chi/jwtauth"
	"github.com/jpincas/tormenta"
	"github.com/robfig/cron"
)

// Create an app instance
var app Application

type Application struct {
	Config    Config
	Router    *chi.Mux
	Scheduler *cron.Cron
	DB        *tormenta.DB
	Data      Data
	Results   Results
	PreVotes  *cache.Cache
}

type Config struct {
	Port             int    `json:"port"`
	TestMode         bool   `json:"testMode"`
	DBDirectory      string `json:"dbDirectory"`
	DataDirectory    string `json:"dataDirectory"`
	VoteWebhook      string `json:"voteWebhook"`
	VoteToBlockchain bool   `json:"voteToBlockchain"`
	BlockchainHost   string `json:"blockchainHost"`
	KGraphAPIKey  string `json:"kGraphAPIKey"`
}

type Data struct {
	Charities map[string]Charity
	// Representatives has internal id as the key whilst SuspendedReps has the external id as the key
	Representatives map[string]Representative
	SuspendedReps   map[string]Representative
}

func runApplication(configFile string) {
	// Apply App level config
	app.applyConfig(configFile)

	// Initiate the router
	tokenAuth := jwtauth.New("HS256", []byte("secret"), nil)
	app.initRouter(tokenAuth)

	// Init results maps
	app.Results = initResults()

	// Startup jobs
	go app.runStartupJobs()

	// Job Scheduler
	app.scheduleJobs()

	// Cache
	app.PreVotes = cache.New(5*time.Minute, 10*time.Minute)

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

	r.Use(middleware.Recoverer)

	// Set up routes
	r.Route("/appapi", func(r chi.Router) {
		r.Get("/charities", ListCharities)
		r.Get("/recentvotes", ListRecentVotes)
		r.Get("/results", GetResults)
		r.Post("/prevote", RegisterPreVote)
		r.Get("/representatives", ListRepresentatives)
		r.Post("/representatives/search", SearchRepresentative)
		r.Post("/representatives", CreateRepresentative)
		r.Delete("/representatives/{id:[A-Z]+}", SuspendRepresentative)
	})

	r.Route("/webhooks", func(r chi.Router) {
		r.Get("/"+a.Config.VoteWebhook, ReceiveVote)
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
	a.readRepresentatives()
}

func (a *Application) readCharities() error {
	f, err := os.Open(a.Config.DataDirectory + "/charities.csv")
	if err != nil {
		return err
	}
	defer f.Close()

	csvr := csv.NewReader(f)

	charities := map[string]Charity{}
	for {
		record, err := csvr.Read()
		// Stop at EOF.
		if err == io.EOF {
			break
		} else if err != nil {
			return err
		}

		id := record[0]
		name := record[1]

		charities[id] = Charity{id, name}
	}

	Log(LogModuleStartup, true, "Read in list of charities OK", nil)
	a.Data.Charities = charities
	return nil
}

func (a *Application) readRepresentatives() error {
	seedFile, err := os.Open(a.Config.DataDirectory + "/representatives_seed.csv")
	if err != nil {
		return err
	}
	defer seedFile.Close()

	csvr := csv.NewReader(seedFile)

	representatives := map[string]Representative{}
	suspendRepresentatives := map[string]Representative{}
	for {
		record, err := csvr.Read()
		// Stop at EOF.
		if err == io.EOF {
			break
		} else if err != nil {
			return err
		}

		id := record[0]
		title := record[1]
		profession := record[2]
		externalId := record[3]
		suspended, err := strconv.ParseBool(record[4])
		// TODO EdS: handle err

		representatives[id] = Representative{id, title, profession, externalId, suspended}
		if suspended {
			suspendRepresentatives[externalId] = Representative{id, title, profession, externalId, suspended}
		}
	}

	Log(LogModuleStartup, true, "Read in seed list of representatives OK", nil)

	// TODO EdS: Refactor this function - probably do not need two csv's
	dbFile, err := os.Open(a.Config.DataDirectory + "/representatives_db.csv")
	if err != nil {
		return err
	}
	defer dbFile.Close()

	csvr = csv.NewReader(dbFile)

	for {
		record, err := csvr.Read()
		// Stop at EOF.
		if err == io.EOF {
			break
		} else if err != nil {
			return err
		}

		id := record[0]
		title := record[1]
		profession := record[2]
		externalId := record[3]
		suspended, err := strconv.ParseBool(record[4])

		representatives[id] = Representative{id, title, profession, externalId, suspended}
		if suspended {
			suspendRepresentatives[externalId] = Representative{id, title, profession, externalId, suspended}
		}
	}

	Log(LogModuleStartup, true, "Read in db list of representatives OK", nil)

	a.Data.Representatives = representatives
	a.Data.SuspendedReps = suspendRepresentatives
	return nil
}

func (a Application) runStartupJobs() {
	updateResults()
	Log(LogModuleStartup, true, "Ran startup jobs OK", nil)
}

func (a *Application) scheduleJobs() {
	a.Scheduler = cron.New()

	a.Scheduler.AddFunc("@every 5m", func() { updateResults() })

	a.Scheduler.Start()

	Log(LogModuleStartup, true, "Job scheduler initialised OK", nil)
}

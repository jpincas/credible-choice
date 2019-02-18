package main

import (
	"flag"
)

var configFile = flag.String("cfg", "config-local", "Name of config file to use")

func main() {
	// Parse argument flags
	flag.Parse()

	// Run the app
	application := run(*configFile)

	// Defer disconnection of tenants
	defer application.close()
}

package main

import (
	"encoding/csv"
	"os"
	"strconv"
)

func rewriteRepresentativeCSV() {
	file, err := os.Create(app.Config.DataDirectory + "/representatives_db.csv")
	defer file.Close()

	if err != nil {
		Log(LogModuleCsv, false, "could not create representatives_db.csv file", err)
	}

	csvw := csv.NewWriter(file)
	defer csvw.Flush()
	var r = []string{"", "", "", "", ""}

	for _, rep := range app.Data.Representatives {
		r[0] = rep.ID
		r[1] = rep.Name
		r[2] = rep.Profession
		r[3] = rep.ExternalId
		r[4] = strconv.FormatBool(rep.Suspended)
		err := csvw.Write(r)
		checkError("could not print representative to csv", err, rep)
	}
}

func checkError(mess string, err error, r Representative) {
	if err != nil {
		Log(LogModuleCsv, true, "could not print "+r.Name+" to representatives_db.csv", err)
	}
}

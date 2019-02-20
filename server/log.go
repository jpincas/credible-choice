package main

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/wsxiaoys/terminal/color"
)

const defaultErrorText = "No error was assigned to this log entry"

const (
	LogModuleLog            = "log"
	LogModuleConfig         = "config"
	LogModuleSettings       = "settings"
	LogModuleStartup        = "startup"
	LogModuleVote           = "vote"
	LogModuleHandlers = "handlers"
	LogModuleRepresentative = "representative"
	LogModuleWiki           = "wiki"
)

// LogEntry represents an entry into the system log
type LogEntry struct {
	ID              int
	Timestamp       time.Time
	IsOK            bool
	Module, Message string
	Error           error
}

func newLogEntry(module string, isOk bool, message string, err error) LogEntry {
	return LogEntry{
		Timestamp: time.Now().UTC(),
		IsOK:      isOk,
		Module:    module,
		Message:   message,
		Error:     err,
	}
}

func (logEntry LogEntry) formatForDisplay() string {
	var entryType string
	var errorText string

	if logEntry.IsOK {
		entryType = color.Sprint("@gOK")
	} else {
		entryType = color.Sprint("@rERROR")
		if logEntry.Error != nil {
			errorText = logEntry.Error.Error()
		} else {
			errorText = defaultErrorText
		}
	}

	if logEntry.Error != nil {
		errorText = color.Sprint("| @r" + errorText)
	}

	return fmt.Sprintf("%s | %s | %s %s", strings.ToUpper(logEntry.Module), entryType, logEntry.Message, errorText)
}

//writeLogEntry formats and writes a log to the stdout
func (logEntry LogEntry) write() {
	log.Println(logEntry.formatForDisplay())
	return
}

//Log is the main function to lodge a log entry
func Log(module string, isOk bool, message string, err error) {
	l := newLogEntry(module, isOk, message, err)
	l.write()
}

//LogFatal lodges a log entry and exits
func LogFatal(module string, isOk bool, message string, err error) {
	l := newLogEntry(module, isOk, message, err)
	l.write()
	os.Exit(1)
}

package main

import (
	"encoding/json"
	"net/http"
)

const (
	errorTypeDatabase                               = "Database access"
	errorTypeInvalidRequestBody                     = "Invalid request body"
	errorTypeInvalidLoginCredentials                = "User not found"
	errorTypeJWTCreation                            = "Problem creating JWT"
	errorTypeBadRequest                             = "Bad request"
	errorTypeEntityNotFound                         = "Requested entity not found"
	errorTypeBodyRead                               = "Could not read request body"
	errorTypeInvalidBody                            = "Request body invalid JSON"
	errorTypeMarshall                               = "Could not create JSON"
	errorTypeNoTokenPresent                         = "no jwt present"
	errorTypeInvalidToken                           = "invalid jwt"
	errorTypeNoAdminRole                            = "role does not have administrator privileges"
	errorTypeNoUserID                               = "no user id"
	errorTypeEntityInvalid                          = "entity did not pass validations"
	errorTypeCannotExecuteAction                    = "action cannot be executed on this entity"
	errorTypeCannotExecuteActionOnEntityInThatState = "action cannot be executed on this entity due to its state"
)

type ErrorResponse struct {
	Type  string `json:"type"`
	Error string `json:"error"`
	Code  int    `json:"code"`
}

var ErrorCodeLookup = map[string]int{
	errorTypeDatabase:                               http.StatusInternalServerError,
	errorTypeInvalidRequestBody:                     http.StatusBadRequest,
	errorTypeInvalidLoginCredentials:                http.StatusUnauthorized,
	errorTypeJWTCreation:                            http.StatusInternalServerError,
	errorTypeBadRequest:                             http.StatusBadRequest,
	errorTypeEntityNotFound:                         http.StatusBadRequest,
	errorTypeBodyRead:                               http.StatusBadRequest,
	errorTypeInvalidBody:                            http.StatusBadRequest,
	errorTypeMarshall:                               http.StatusInternalServerError,
	errorTypeNoTokenPresent:                         http.StatusUnauthorized,
	errorTypeInvalidToken:                           http.StatusUnauthorized,
	errorTypeNoAdminRole:                            http.StatusUnauthorized,
	errorTypeNoUserID:                               http.StatusUnauthorized,
	errorTypeEntityInvalid:                          http.StatusBadRequest,
	errorTypeCannotExecuteAction:                    http.StatusBadRequest,
	errorTypeCannotExecuteActionOnEntityInThatState: 419,
}

func render(w http.ResponseWriter, code int, toRender interface{}) {
	json, err := json.Marshal(toRender)
	if err != nil {
		respondWithError(w, errorTypeMarshall, err)
		return
	}

	w.WriteHeader(code)
	w.Header().Set("Content-Type", "application/json")
	w.Write(json)
	return
}

func respond(w http.ResponseWriter, toRender interface{}) {
	render(w, http.StatusOK, toRender)
}

func respondOK(w http.ResponseWriter) {
	w.WriteHeader(http.StatusOK)
	return
}

func lookupErrorCode(errorType string) int {
	code, ok := ErrorCodeLookup[errorType]
	if !ok {
		return http.StatusInternalServerError
	}

	return code
}

func respondWithError(w http.ResponseWriter, errorType string, err error) {
	code := lookupErrorCode(errorType)

	var errorMessage string
	if err == nil {
		errorMessage = ""
	} else {
		errorMessage = err.Error()
	}

	errorResponse := ErrorResponse{
		Type:  errorType,
		Error: errorMessage,
		Code:  code,
	}

	render(w, code, errorResponse)
}

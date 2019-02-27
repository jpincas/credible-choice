package main

import (
	"fmt"
	"net/http"
)

// CACHING

const (
	cacheControlHeaderKey     = "Cache-Control"
	cacheControlNoCacheString = "no-cache"
	cacheControlSecondsString = "public, max-age=%v"
)

func setSecondsCacheHeader(w http.ResponseWriter, seconds int) {
	expiry := fmt.Sprintf(cacheControlSecondsString, seconds)
	w.Header().Set(cacheControlHeaderKey, expiry)
}

func noCache(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set(cacheControlHeaderKey, cacheControlNoCacheString)
		next.ServeHTTP(w, r)
	})
}

func cacheFor1Hour(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		setSecondsCacheHeader(w, 3600)
		next.ServeHTTP(w, r)
	})
}

func cacheFor1Minute(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		setSecondsCacheHeader(w, 60)
		next.ServeHTTP(w, r)
	})
}

func cacheFor15Seconds(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		setSecondsCacheHeader(w, 15)
		next.ServeHTTP(w, r)
	})
}

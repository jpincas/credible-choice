package main

import "encoding/xml"

type VoteNotificationWrapper struct {
	XMLName          xml.Name         `xml:"messages"`
	VoteNotification VoteNotification `xml:"message"`
}

type VoteNotification struct {
	// Gateway credentials
	Username string `xml:"username"`
	Password string `xml:"password"`

	MobileNumber             string `xml:"number"`
	MessageText              string `xml:"message_text"`
	KeywordAndDonationAmount string `xml:"keyword"`
}

package models

import "time"

type Empty struct{}

// API RESPONSES

// since different notations and []DeviceTokens would complicate decoding in Swift
type UserResponse struct {
	UserID   string `json:"userID"`
	Email    string `json:"email"`
	FullName string `json:"fullName"`
	Username string `json:"username"`
}

type TeamResponse struct {
	Name    string `json:"name"`
	Slug    string `json:"slug"`
	Details string `json:"details"`
}

type IdentResponse struct {
	Time     time.Time `json:"time"`
	UserText string `json:"userText"`
}

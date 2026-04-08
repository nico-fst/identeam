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

func (u User) ToResponse() UserResponse {
	return UserResponse{
		UserID:   u.UserID,
		Email:    u.Email,
		FullName: u.FullName,
		Username: u.Username,
	}
}

type TeamResponse struct {
	Name    string `json:"name"`
	Slug    string `json:"slug"`
	Details string `json:"details"`
}

func (t Team) ToResponse() TeamResponse {
	return TeamResponse{
		Name:    t.Name,
		Slug:    t.Slug,
		Details: t.Details,
	}
}

type IdentResponse struct {
	Time     time.Time `json:"time"`
	UserText string    `json:"userText"`
}

func (i Ident) ToResponse() IdentResponse {
	return IdentResponse{
		Time:     i.Time,
		UserText: i.UserText,
	}
}

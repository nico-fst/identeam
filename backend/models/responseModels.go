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

type Users []User

func (users Users) ToResponses() []UserResponse {
	res := make([]UserResponse, 0, len(users))

	for _, user := range users {
		res = append(res, user.ToResponse())
	}

	return res
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

type Teams []*Team

func (teams Teams) ToResponses() []TeamResponse {
	res := make([]TeamResponse, 0, len(teams))

	for _, team := range teams {
		if team == nil {
			continue
		}
		res = append(res, team.ToResponse())
	}

	return res
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

type Idents []Ident

func (idents Idents) ToResponses() []IdentResponse {
	res := make([]IdentResponse, 0, len(idents))

	for _, ident := range idents {
		res = append(res, ident.ToResponse())
	}

	return res
}

type UserWeeklyTargetResponse struct {
	TimeStart   time.Time `json:"timeStart"`
	TargetCount uint      `json:"targetCount"`
}

func (t UserWeeklyTarget) ToResponse() UserWeeklyTargetResponse {
	return UserWeeklyTargetResponse{
		TimeStart:   t.TimeStart,
		TargetCount: t.TargetCount,
	}
}

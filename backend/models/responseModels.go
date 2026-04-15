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

func (u User) ToDTO() UserResponse {
	return UserResponse{
		UserID:   u.UserID,
		Email:    u.Email,
		FullName: u.FullName,
		Username: u.Username,
	}
}

type Users []User

func (users Users) ToDTOs() []UserResponse {
	res := make([]UserResponse, 0, len(users))

	for _, user := range users {
		res = append(res, user.ToDTO())
	}

	return res
}

type TeamResponse struct {
	Name    string `json:"name"`
	Slug    string `json:"slug"`
	Details string `json:"details"`
}

func (t Team) ToDTO() TeamResponse {
	return TeamResponse{
		Name:    t.Name,
		Slug:    t.Slug,
		Details: t.Details,
	}
}

type Teams []*Team

func (teams Teams) ToDTOs() []TeamResponse {
	res := make([]TeamResponse, 0, len(teams))

	for _, team := range teams {
		if team == nil {
			continue
		}
		res = append(res, team.ToDTO())
	}

	return res
}

type IdentResponse struct {
	Time     time.Time `json:"time"`
	UserText string    `json:"userText"`
}

func (i Ident) ToDTO() IdentResponse {
	return IdentResponse{
		Time:     i.Time,
		UserText: i.UserText,
	}
}

type Idents []Ident

func (idents Idents) ToDTOs() []IdentResponse {
	res := make([]IdentResponse, 0, len(idents))

	for _, ident := range idents {
		res = append(res, ident.ToDTO())
	}

	return res
}

type TeamWeekMemberResponse struct {
	User        UserResponse    `json:"user"`
	TargetCount uint            `json:"targetCount"`
	Idents      []IdentResponse `json:"idents"`
}

type TeamWeekResponse struct {
	Slug      string                   `json:"slug"`
	TargetSum uint                     `json:"targetSum"`
	IdentSum  uint                     `json:"identSum"`
	Members   []TeamWeekMemberResponse `json:"members"`
}

func NewTeamWeekResponse(teamSlug string, targets []UserWeeklyTarget) TeamWeekResponse {
	resp := TeamWeekResponse{
		Slug:      teamSlug,
		TargetSum: 0,
		IdentSum:  0,
		Members:   make([]TeamWeekMemberResponse, 0, len(targets)),
	}

	if len(targets) > 0 {
		resp.Slug = targets[0].Team.Slug
	}

	for _, target := range targets {
		resp.TargetSum += target.TargetCount
		resp.IdentSum += uint(len(target.Idents))
		resp.Members = append(resp.Members, TeamWeekMemberResponse{
			User:        target.User.ToDTO(),
			TargetCount: target.TargetCount,
			Idents:      Idents(target.Idents).ToDTOs(),
		})
	}

	return resp
}

type UserWeeklyTargetResponse struct {
	TimeStart   time.Time `json:"timeStart"`
	TargetCount uint      `json:"targetCount"`
}

func (t UserWeeklyTarget) ToDTO() UserWeeklyTargetResponse {
	return UserWeeklyTargetResponse{
		TimeStart:   t.TimeStart,
		TargetCount: t.TargetCount,
	}
}

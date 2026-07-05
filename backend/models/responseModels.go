package models

import (
	"context"
	"identeam/internal/media"
	"time"
)

type Empty struct{}

// API RESPONSES

// since different notations and []DeviceTokens would complicate decoding in Swift
type UserDTO struct {
	UserID   string            `json:"userID"`
	Email    string            `json:"email"`
	Nickname string            `json:"nickname"`
	Username string            `json:"username"`
	Avatar   PresignedResponse `json:"avatar"`
}

func (u User) ToDTO(ctx context.Context, r2Client *media.R2Client) UserDTO {
	resp := UserDTO{
		UserID:   u.UserID,
		Email:    u.Email,
		Nickname: u.Nickname,
		Username: u.Username,
	}

	if r2Client == nil || u.AvatarS3Key == "" {
		return resp
	}

	// add presigned Avatar
	expiresAt := time.Now().Add(time.Hour * 24)
	imageURL, err := r2Client.PresignGetObject(ctx, u.AvatarS3Key, expiresAt)
	if err != nil {
		// swallows error - catching would complicate entire toDTO process
		print("ERROR presigning URL for User.Avatar:", err.Error())
	} else {
		resp.Avatar = PresignedResponse{
			Key:          u.AvatarS3Key,
			PresignedURL: imageURL,
			ExpiresAt:    expiresAt,
		}
	}

	return resp
}

type Users []User

func (users Users) ToDTOs(ctx context.Context, r2Client *media.R2Client) []UserDTO {
	res := make([]UserDTO, 0, len(users))

	for _, user := range users {
		res = append(res, user.ToDTO(ctx, r2Client))
	}

	return res
}

type TeamDTO struct {
	Name    string `json:"name"`
	Slug    string `json:"slug"`
	Details string `json:"details"`
}

func (t Team) ToDTO() TeamDTO {
	return TeamDTO{
		Name:    t.Name,
		Slug:    t.Slug,
		Details: t.Details,
	}
}

type Teams []*Team

func (teams Teams) ToDTOs() []TeamDTO {
	res := make([]TeamDTO, 0, len(teams))

	for _, team := range teams {
		if team == nil {
			continue
		}
		res = append(res, team.ToDTO())
	}

	return res
}

type IdentDTO struct {
	ID       uint              `json:"id"`
	Time     time.Time         `json:"time"`
	UserText string            `json:"userText"`
	Image    PresignedResponse `json:"image"`
	Comments []CommentDTO      `json:"comments"`
}

func (i Ident) ToDTO(ctx context.Context, r2Client *media.R2Client) IdentDTO {
	resp := IdentDTO{
		ID:       i.ID,
		Time:     i.Time,
		UserText: i.UserText,
		// Image s. below
		Comments: Comments(i.Comments).ToDTOs(ctx, r2Client), // Cast since Go expects exact same type ([]Comment != Comments)
	}

	if r2Client == nil || i.ImageS3Key == "" {
		return resp
	}

	// add presigned Image
	expiresAt := time.Now().Add(time.Hour * 24)
	imageURL, err := r2Client.PresignGetObject(ctx, i.ImageS3Key, expiresAt)
	if err != nil {
		// swallows error - catching would complicate entire toDTO process
		print("ERROR presigning URL for Ident:", err.Error())
	} else {
		resp.Image = PresignedResponse{
			Key:          i.ImageS3Key,
			PresignedURL: imageURL,
			ExpiresAt:    expiresAt,
		}
	}

	return resp
}

type Idents []Ident

func (idents Idents) ToDTOs(ctx context.Context, r2Client *media.R2Client) []IdentDTO {
	res := make([]IdentDTO, 0, len(idents))

	for _, ident := range idents {
		res = append(res, ident.ToDTO(ctx, r2Client))
	}

	return res
}

type CommentDTO struct {
	ID   uint      `json:"id"`
	Time time.Time `json:"time"`
	Text string    `json:"text"`
	User UserDTO   `json:"user"`
}

func (c Comment) ToDTO(ctx context.Context, r2Client *media.R2Client) CommentDTO {
	return CommentDTO{
		ID:   c.ID,
		Time: c.CreatedAt,
		Text: c.Text,
		User: c.User.ToDTO(ctx, r2Client),
	}
}

type Comments []Comment

func (comments Comments) ToDTOs(ctx context.Context, r2Client *media.R2Client) []CommentDTO {
	res := make([]CommentDTO, 0, len(comments))

	for _, comment := range comments {
		res = append(res, comment.ToDTO(ctx, r2Client))
	}

	return res
}

type TeamWeekMemberResponse struct {
	User        UserDTO    `json:"user"`
	TargetCount uint       `json:"targetCount"`
	Idents      []IdentDTO `json:"idents"`
}

type TeamWeekResponse struct {
	Slug      string                   `json:"slug"`
	TargetSum uint                     `json:"targetSum"`
	IdentSum  uint                     `json:"identSum"`
	Members   []TeamWeekMemberResponse `json:"members"`
}

func NewTeamWeekResponse(ctx context.Context, r2Client *media.R2Client, teamSlug string, targets []UserWeeklyTarget) TeamWeekResponse {
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
			User:        target.User.ToDTO(ctx, r2Client),
			TargetCount: target.TargetCount,
			Idents:      Idents(target.Idents).ToDTOs(ctx, r2Client),
		})
	}

	return resp
}

type UserWeeklyTargetDTO struct {
	TimeStart   time.Time `json:"timeStart"`
	TargetCount uint      `json:"targetCount"`
}

func (t UserWeeklyTarget) ToDTO() UserWeeklyTargetDTO {
	return UserWeeklyTargetDTO{
		TimeStart:   t.TimeStart,
		TargetCount: t.TargetCount,
	}
}

type PresignedResponse struct {
	Key          string    `json:"key"`
	PresignedURL string    `json:"presignedURL"`
	ExpiresAt    time.Time `json:"expiresAt"`
}

type CommitS3Response struct {
	Key string `json:"key"`
}

type LocalNotificationDTO struct {
	Title string    `json:"title"`
	Body  string    `json:"body"`
	Date  time.Time `json:"date"`
}

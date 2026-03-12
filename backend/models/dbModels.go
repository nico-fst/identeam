package models

import (
	"strings"
	"time"

	"gorm.io/gorm"
)

type User struct {
	UserID string `gorm:"uniqueIndex;not null"`
	Email  string `gorm:"uniqueIndex;not null"`

	AuthProvider string  // "apple" | "password"
	PasswordHash *string // Pointer is nullable

	FullName string
	Username string `gorm:"unique"`

	// GORM & Relations
	gorm.Model                 // provides ID, CreatedAt, UpdatedAt, DeletedAt
	DeviceTokens []DeviceToken // 1:N - GORM expects for DeviceToken.UserID
	Teams        []*Team       `gorm:"many2many:users_teams;"`
}

func (user *User) BeforeSave(tx *gorm.DB) (err error) {
	user.Email = strings.ToLower(user.Email)
	user.Username = strings.ToLower(user.Username)
	return nil
}

type DeviceToken struct {
	Token    string `gorm:"uniqueIndex"`
	Platform string // ios | iPadOS | macOS

	// GORM & Relations
	gorm.Model
	UserID uint // standard FK for GORM
}

type Team struct {
	// Public
	Name    string `gorm:"not null"`
	Slug    string `gorm:"uniqueIndex"` // for urls
	Details string

	// GORM & Relations
	gorm.Model
	Users []*User `gorm:"many2many:users_teams;"`
}

func (team *Team) BeforeSave(tx *gorm.DB) (err error) {
	team.Slug = strings.ToLower(team.Slug)
	return nil
}

type UserWeeklyTarget struct {
	// Composite Unique Index with UserID, TeamID
	TimeStart time.Time `gorm:"not null;uniqueIndex:idx_user_team_week"`
	UserID    uint      `gorm:"not null;uniqueIndex:idx_user_team_week"`
	TeamID    uint      `gorm:"not null;uniqueIndex:idx_user_team_week"`

	TargetCount uint `gorm:"not null"`

	// GORM & Relations
	gorm.Model
	Team   Team    // gorm-idiomatic: allows .Joins("Team")
	Idents []Ident // UserWeeklyTarget has many Idents
}

type Ident struct {
	Time     time.Time `gorm:"not null"`
	UserText string

	// GORM & Relations
	gorm.Model
	UserWeeklyTargetID uint // UserWeeklyTarget has many Idents
}

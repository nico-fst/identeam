package models

import (
	"errors"
	"strings"
	"time"

	"gorm.io/gorm"
)

type User struct {
	UserID string `gorm:"uniqueIndex;not null"`
	Email  string `gorm:"uniqueIndex;not null"`

	AuthProvider string  // "apple" | "password"
	PasswordHash *string // Pointer is nullable

	Nickname string
	Username string `gorm:"unique"`

	AvatarS3Key string

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
	Name                 string `gorm:"not null"`
	Slug                 string `gorm:"uniqueIndex"` // for urls
	Details              string
	NotificationTemplate *string

	// GORM & Relations
	gorm.Model
	Users []*User `gorm:"many2many:users_teams;"`
}

func (team *Team) BeforeSave(tx *gorm.DB) (err error) {
	team.Slug = strings.ToLower(team.Slug)

	if team.NotificationTemplate != nil {
		trimmed := strings.TrimSpace(*team.NotificationTemplate)
		if trimmed == "" {
			team.NotificationTemplate = nil
			return nil
		}
		team.NotificationTemplate = &trimmed

		if strings.Count(trimmed, "{{name}}") != 1 {
			return errors.New("notification template must contain {{name}} exactly once")
		}
	}

	return nil
}

type Target struct {
	// Composite Unique Index with UserID, TeamID
	TimeStart time.Time `gorm:"not null;uniqueIndex:idx_targets_user_team_time"`
	UserID    uint      `gorm:"not null;uniqueIndex:idx_targets_user_team_time"`
	TeamID    uint      `gorm:"not null;uniqueIndex:idx_targets_user_team_time"`
	// Kept temporarily so existing databases with a NOT NULL target_count column
	// can still create targets during the TargetDay migration.
	LegacyTargetCount uint `gorm:"column:target_count;not null;default:0"`

	// GORM & Relations
	gorm.Model
	User       User // gorm-idiomatic: allows .Joins("Team")
	Team       Team
	TargetDays []TargetDay `gorm:"constraint:OnDelete:CASCADE;"`
	Idents     []Ident     // Target has many Idents
}

type TargetDay struct {
	ID   uint      `gorm:"primaryKey"` // manual since no gorm.Model
	Date time.Time `gorm:"type:date;not null;uniqueIndex:idx_target_day"`

	// GORM & Relations
	// NO Soft-Delete via gorm.Model - could block insertion on same date
	// gorm.Model
	TargetID uint `gorm:"not null;uniqueIndex:idx_target_day"`
}

type Ident struct {
	Time     time.Time `gorm:"not null"`
	UserText string

	ImageS3Key string

	// GORM & Relations
	gorm.Model
	TargetID uint // Target has many Idents
	Comments []Comment
}

type Comment struct {
	Text    string `gorm:"not null"`
	IdentID uint   `gorm:"not null;index"`
	UserID  uint   `gorm:"not null;index"`

	// GORM & Relations
	gorm.Model
	Ident Ident
	User  User
}

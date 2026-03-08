package models

import (
	"strings"

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
	DeviceTokens []DeviceToken // 1:N - GORM expectes for DeviceToken.UserID
	Teams        []*Team       `gorm:"many2many:users_teams;"`
}

func (user *User) BeforeSave(tx *gorm.DB) (err error) {
	user.Email = strings.ToLower(user.Email)
	user.Username = strings.ToLower(user.Username)
	return nil
}

func (team *Team) BeforeSave(tx *gorm.DB) (err error) {
	team.Slug = strings.ToLower(team.Slug)
	return nil
}

type DeviceToken struct {
	Token    string `gorm:"unique"`
	Platform string // ios | iPadOS | macOS
	UserID   uint   // standard FK for GORM

	// GORM & Relations
	gorm.Model
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

package models

import (
	"gorm.io/gorm"
)

type User struct {
	UserID   string `gorm:"uniqueIndex;not null"`
	Email    string `gorm:"uniqueIndex;not null"`
	FullName string
	Username string `gorm:"unique"`

	// GORM & Relations
	gorm.Model                 // provides ID, CreatedAt, UpdatedAt, DeletedAt
	DeviceTokens []DeviceToken // 1:N - GORM expectes for DeviceToken.UserID
	Teams       []*Team      `gorm:"many2many:users_teams;"`
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
	Name        string `gorm:"not null"`
	Slug        string `gorm:"uniqueIndex"` // for urls
	Description string

	// Visibility, Joining
	// TODO join code

	// GORM & Relations
	gorm.Model
	Users []*User `gorm:"many2many:users_teams;"`
}

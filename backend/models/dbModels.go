package models

import (
	"gorm.io/gorm"
)

type User struct {
	gorm.Model        // provides ID, CreatedAt, UpdatedAt, DeletedAt
	UserID     string `gorm:"uniqueIndex;not null"`
	Email      string `gorm:"uniqueIndex;not null"`
	FullName   string
	Username   string `gorm:"unique"`

	DeviceTokens []DeviceToken // defines 1:N - GORM expectes for DeviceToken.UserID
}

type DeviceToken struct {
	gorm.Model
	Token    string `gorm:"unique"`
	Platform string // ios | iPadOS | macOS

	UserID uint // standard FK for GORM
}

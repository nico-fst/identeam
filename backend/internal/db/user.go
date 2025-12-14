package db

import (
	"context"
	"identeam/models"
	"log"

	"gorm.io/gorm"
)

// Returns user if exists, otherwise nil
func GetUserById(ctx context.Context, db *gorm.DB, userID string) (*models.User, error) {
	user, err := gorm.G[models.User](db).
		Where("user_id = ?", userID).
		First(ctx)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			log.Printf("Failed to lookup non-existing user in DB: %v", userID)
		}
		return nil, err
	}

	log.Printf("Looked up user with id %v in DB", userID)
	return &user, nil
}

// Tries creating user
func CreateUser(ctx context.Context, db *gorm.DB, user models.User) (*models.User, error) {
	err := gorm.G[models.User](db).
		Create(ctx, &user)
	if err != nil {
		log.Printf("ERROR creating user %v in DB: %v", user, err)
		return nil, err
	}

	log.Printf("Created user with id %v in DB", user.UserID)
	return &user, nil
}

// Gets or creates user -> true if got
func GetElseCreateUser(ctx context.Context, db *gorm.DB, user models.User) (bool, error) {
	_, err := GetUserById(ctx, db, user.UserID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			_, createErr := CreateUser(ctx, db, user)
			return false, createErr
		}
		return true, err // bool not important
	}
	return true, nil
}

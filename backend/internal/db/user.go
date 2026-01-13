package db

import (
	"context"
	"errors"
	"identeam/models"
	"log"
	"unicode/utf8"
	"strings"

	"gorm.io/gorm"
)

var (
	ErrFullNameTooLong = errors.New("'Your Name' is too long (max. 10 chars) >:(")
	ErrUsernameTaken   = errors.New("This username is not available :O")
)

// Returns user if exists in DB, otherwise nil
func GetUserById(ctx context.Context, db *gorm.DB, userID string) (*models.User, error) {
	var user models.User
	err := db.Model(&models.User{}).Preload("Teams").Where("user_id = ?", userID).First(&user).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			log.Printf("Failed to lookup non-existing user in DB: %v", userID)
		}
		return nil, err
	}

	log.Printf("Looked up user with id %v in DB", userID)
	return &user, nil
}

// Tries creating given user in DB
func CreateUser(ctx context.Context, db *gorm.DB, user models.User) (*models.User, error) {
	err := gorm.G[models.User](db).
		Create(ctx, &user)
	if err != nil {
		log.Printf("ERROR creating user %v in DB: %v", user, err)
		return nil, err
	}

	if user.FullName != "" {
		log.Printf("Defaulting user.Username %v with its fullname %v", user.UserID, user.FullName)
		user.Username = user.FullName
	} else if at := strings.Index(user.Email, "@"); at != -1 {
		log.Printf("Defaulting user.Username %v with Email (%v) Prefix %v since FullName is empty", user.UserID, user.Email, user.Email[:at])
		user.Username = user.Email[:at]
	}

	log.Printf("Created user with id %v in DB", user.UserID)
	return &user, nil
}

// Gets or creates user -> true <=> new user crated
func GetElseCreateUser(ctx context.Context, db *gorm.DB, input models.User) (bool, models.User, error) {
	foundUser, err := GetUserById(ctx, db, input.UserID)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			createdUser, createErr := CreateUser(ctx, db, input)
			if createErr != nil {
				return false, models.User{}, createErr
			}
			return true, *createdUser, nil
		}
		return false, models.User{}, err
	}

	return false, *foundUser, nil
}

// Update FullName or Username of given user
func UpdateUserDetails(ctx context.Context, db *gorm.DB, user models.User, newUserDetails models.User) (models.User, error) {
	// TODO allow changing email in future

	// Guard: |FullName| <= 10
	if utf8.RuneCountInString(newUserDetails.FullName) > 10 {
		log.Printf("ERROR updating username %v -> %v (too long)", user.FullName, newUserDetails.FullName)
		return models.User{}, ErrFullNameTooLong
	}

	var userToUpdate models.User
	if err := db.Where("user_id = ?", newUserDetails.UserID).First(&userToUpdate).Error; err != nil {
		return models.User{}, err
	}

	updates := map[string]interface{}{
		"FullName": newUserDetails.FullName,
		"Username": newUserDetails.Username,
	}

	if err := db.Model(&userToUpdate).Updates(updates).Error; err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			return models.User{}, ErrUsernameTaken
		}
		return models.User{}, err
	}

	updatedUser, err := GetUserById(ctx, db, newUserDetails.UserID)
	if err != nil {
		return models.User{}, err
	}

	return *updatedUser, nil
}

func DerefUsers(users []*models.User) []models.User {
	res := make([]models.User, 0, len(users))

	for _, u := range users {
		if u == nil {
			continue
		}
		res = append(res, *u)
	}

	return res
}

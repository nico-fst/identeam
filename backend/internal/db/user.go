package db

import (
	"context"
	"errors"
	"identeam/models"
	"log"
	"strings"
	"unicode/utf8"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

var (
	ErrFullNameTooLong = errors.New("'Your Name' is too long (max. 15 chars) >:(")
	ErrUsernameTaken   = errors.New("This username is not available :O")
)

// Returns user if exists in DB, otherwise nil
func GetUserById(ctx context.Context, db *gorm.DB, userID string) (*models.User, error) {
	var user models.User
	err := db.Model(&models.User{}).
		Preload("Teams").
		Where("user_id = ?", userID).
		First(&user).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			log.Printf("Failed to lookup non-existing user in DB with user_id %v", userID)
		}
		return nil, err
	}

	log.Printf("Looked up user with id %v in DB", userID)
	return &user, nil
}

func GetUserByMail(ctx context.Context, db *gorm.DB, email string) (*models.User, error) {
	var user models.User
	err := db.Model(&models.User{}).
		Preload("Teams").
		Where("email", strings.ToLower(strings.TrimSpace(email))).
		First(&user).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			log.Printf("Failed to lookup non-existing uesr in DB with email %v", email)
		}
		return nil, err
	}

	log.Printf("Looked up user with email %v in DB", email)
	return &user, nil
}

// Tries creating given user in DB
func CreateUser(ctx context.Context, db *gorm.DB, user models.User) (*models.User, error) {
	if user.FullName != "" {
		log.Printf("Defaulting user.Username %v with its fullname %v", user.UserID, user.FullName)
		user.Username = user.FullName
	}
	if at := strings.Index(user.Email, "@"); at != -1 {
		log.Printf("Defaulting user.Username %v with Email (%v) Prefix %v since FullName is empty", user.UserID, user.Email, user.Email[:at])
		user.Username = user.Email[:at]
	}

	err := gorm.G[models.User](db).
		Create(ctx, &user)
	if err != nil {
		log.Printf("ERROR creating user %v in DB: %v", user, err)
		return nil, err
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
	// Guard: |FullName| <= 15
	if utf8.RuneCountInString(newUserDetails.FullName) > 15 {
		log.Printf("ERROR updating username %v -> %v (too long)", user.FullName, newUserDetails.FullName)
		return models.User{}, ErrFullNameTooLong
	}

	var userToUpdate models.User
	if err := db.Where("user_id = ?", newUserDetails.UserID).First(&userToUpdate).Error; err != nil {
		return models.User{}, err
	}

	updates := map[string]interface{}{
		"FullName": newUserDetails.FullName,
		"Username": strings.ToLower(strings.TrimSpace(newUserDetails.Username)),
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

func DoesEmailMatchPassword(ctx context.Context, db *gorm.DB, email string, password string) (bool, *models.User, error) {
	user, err := GetUserByMail(ctx, db, email)
	if err != nil {
		return false, nil, err
	}

	if user.PasswordHash == nil {
		return false, nil, errors.New("user has no password set")
	}

	err = bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(password))
	if err == bcrypt.ErrMismatchedHashAndPassword {
		return false, nil, err
	}
	return err == nil, user, err
}

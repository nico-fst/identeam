package db

import (
	"context"
	"errors"
	"identeam/models"
	"log"

	"gorm.io/gorm"
)

func UpdateUsersDeviceToken(ctx context.Context, db *gorm.DB, user models.User, token models.DeviceToken) (models.User, error) {
	err := db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		// A user should only keep one token per platform. If the app rotated the
		// APNs token on this device, older iOS tokens for the same user can go away.
		if err := tx.
			Where("user_id = ? AND platform = ? AND token <> ?", user.ID, token.Platform, token.Token).
			Delete(&models.DeviceToken{}).Error; err != nil {
			return err
		}

		var existingByToken models.DeviceToken
		// The same physical device can log into another account. In that case the
		// APNs token stays the same, so we "move" the token row to the new user.
		err := tx.Where("token = ?", token.Token).First(&existingByToken).Error
		switch {
		case err == nil:
			existingByToken.UserID = user.ID
			existingByToken.Platform = token.Platform
			if err := tx.Save(&existingByToken).Error; err != nil {
				log.Printf("ERROR reassigning deviceToken %v in DB: %v", token, err)
				return err
			}
			log.Printf("Reassigned existing deviceToken in DB to user %v", user.UserID)
			return nil
		case !errors.Is(err, gorm.ErrRecordNotFound):
			return err
		}

		var existingByUserPlatform models.DeviceToken
		// If this user already has a token for the platform, replace it with the
		// latest value reported by the app.
		err = tx.Where("user_id = ? AND platform = ?", user.ID, token.Platform).First(&existingByUserPlatform).Error
		switch {
		case err == nil:
			if err := tx.Model(&existingByUserPlatform).Update("token", token.Token).Error; err != nil {
				log.Printf("ERROR updating deviceToken %v in DB: %v", token, err)
				return err
			}
			log.Printf("Updated existing deviceToken in DB to %v", token.Token)
			return nil
		case !errors.Is(err, gorm.ErrRecordNotFound):
			return err
		}

		// First token we have ever seen for this user/platform combination.
		token.UserID = user.ID
		if err := tx.Create(&token).Error; err != nil {
			log.Printf("ERROR inserting deviceToken %v into DB: %v", token, err)
			return err
		}
		log.Printf("Inserted deviceToken into DB: %v", token.Token)
		return nil
	})
	if err != nil {
		return models.User{}, err
	}

	updatedUser, err := gorm.G[models.User](db).
		Preload("DeviceTokens", nil).
		Where("id = ?", user.ID).
		First(ctx)
	if err != nil {
		log.Printf("ERROR looking up updated user with id %v in DB: %v", user.UserID, err)
		return models.User{}, err
	}
	return updatedUser, nil
}

func DeleteDeviceToken(ctx context.Context, db *gorm.DB, token string) error {
	_, err := gorm.G[models.DeviceToken](db).
		Where("token = ?", token).
		Delete(ctx)
	if err != nil {
		return err
	}

	return nil
}

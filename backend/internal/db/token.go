package db

import (
	"context"
	"identeam/models"
	"log"

	"gorm.io/gorm"
)

func UpdateUsersDeviceToken(ctx context.Context, db *gorm.DB, user models.User, token models.DeviceToken) (models.User, error) {
	// Try looking up existing object (not directly updating since does not produce error)
	_, err := gorm.G[models.DeviceToken](db).
		Where("user_id = ? AND platform = ?", user.ID, token.Platform).
		First(ctx)
	if err == nil {
		// object Existing => update
		_, err := gorm.G[models.DeviceToken](db).
			Where("user_id = ? AND platform = ?", user.ID, token.Platform).
			Update(ctx, "token", token.Token)
		if err != nil {
			log.Printf("ERROR updating deviceToken %v in DB: %v", token, err)
			return models.User{}, err
		}
		log.Printf("Updated existing deviceToken in DB to %v", token.Token)
	} else {
		// Not existing yet => add object
		if err == gorm.ErrRecordNotFound {
			token.UserID = user.ID
			err := gorm.G[models.DeviceToken](db).
				Create(ctx, &token)
			if err != nil {
				log.Printf("ERROR inserting deviceToken %v into DB: %v", token, err)
				return models.User{}, err
			}
			log.Printf("Inserted deviceToken into DB: %v", token.Token)
		}
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

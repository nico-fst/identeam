package db

import (
	"context"
	"identeam/models"
	"log"

	"gorm.io/gorm"
)

func CreateIdent(ctx context.Context, db *gorm.DB, ident models.Ident) (*models.Ident, error) {
	err := gorm.G[models.Ident](db).
		Create(ctx, &ident)
	if err != nil {
		log.Printf("ERROR creating Ident %v in DB: %v", ident, err)
		return nil, err
	}

	log.Printf("Created Ident with id %v in DB", ident.ID)
	return &ident, nil
}

func GetIdentById(ctx context.Context, db *gorm.DB, identID uint) (*models.Ident, error) {
	var ident models.Ident
	err := db.Model(&models.Ident{}).
		Where("id = ?", identID).
		First(&ident).Error
	if err != nil {
		log.Printf("ERROR looking up Ident with id %v: %v", identID, err)
		return nil, err
	}

	return &ident, nil
}

func UserOwnsIdentInTeam(ctx context.Context, db *gorm.DB, identID uint, userID uint, teamSlug string) (bool, error) {
	var count int64
	err := db.WithContext(ctx).
		Model(&models.Ident{}).
		Joins("JOIN user_weekly_targets ON user_weekly_targets.id = idents.user_weekly_target_id").
		Joins("JOIN teams ON teams.id = user_weekly_targets.team_id").
		Where("idents.id = ?", identID).
		Where("user_weekly_targets.user_id = ?", userID).
		Where("teams.slug = ?", teamSlug).
		Count(&count).Error
	if err != nil {
		log.Printf("ERROR checking ownership for Ident %v, userID %v, teamSlug %v: %v", identID, userID, teamSlug, err)
		return false, err
	}

	return count > 0, nil
}

func DeleteIdent(ctx context.Context, db *gorm.DB, ident models.Ident) error {
	_, err := gorm.G[models.Ident](db).Where("id = ?", ident.ID).Delete(ctx)
	if err != nil {
		log.Printf("ERROR deleting Ident with id %v from DB: %v", ident.ID, err)
		return err
	}

	log.Printf("Deleted Ident with id %v from DB", ident.ID)
	return nil
}

func UpdateIdentKey(ctx context.Context, db *gorm.DB, identID uint, key string) error {
	return db.WithContext(ctx).
		Model(&models.Ident{}).
		Where("id = ?", identID).
		Update("image_s3_key", key).
		Error
}

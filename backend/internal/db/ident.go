package db

import (
	"context"
	"identeam/models"
	"log"

	"gorm.io/gorm"
)

func CreateIdent(ctx context.Context, app AppContext, ident models.Ident) (*models.Ident, error) {
	err := gorm.G[models.Ident](app.Database()).
		Create(ctx, &ident)
	if err != nil {
		log.Printf("ERROR creating Ident %v in DB: %v", ident, err)
		return nil, err
	}

	log.Printf("Created Ident with id %v in DB", ident.ID)
	return &ident, nil
}

func GetIdentById(ctx context.Context, app AppContext, identID uint) (*models.Ident, error) {
	var ident models.Ident
	err := app.Database().Model(&models.Ident{}).
		Where("id = ?", identID).
		First(&ident).Error
	if err != nil {
		log.Printf("ERROR looking up Ident with id %v: %v", identID, err)
		return nil, err
	}

	return &ident, nil
}

func GetIdentsOfTarget(ctx context.Context, app AppContext, targetID uint) ([]models.Ident, error) {
	idents, err := gorm.G[models.Ident](app.Database().Statement.DB).
		Where("target_id = ?", targetID).
		Find(ctx)
	return idents, err
}

func GetIdentsOfTargets(ctx context.Context, app AppContext, targets []models.Target) ([]models.Ident, error) {
	idents := make([]models.Ident, 0)
	for _, t := range targets {
		foundTargets, err := GetIdentsOfTarget(ctx, app, t.ID)
		if err != nil {
			return []models.Ident{}, nil
		}
		idents = append(idents, foundTargets...)
	}
	return idents, nil
}

func UserOwnsIdentInTeam(ctx context.Context, app AppContext, identID uint, userID uint, teamSlug string) (bool, error) {
	var count int64
	err := app.Database().WithContext(ctx).
		Model(&models.Ident{}).
		Joins("JOIN targets ON targets.id = idents.target_id").
		Joins("JOIN teams ON teams.id = targets.team_id").
		Where("idents.id = ?", identID).
		Where("targets.user_id = ?", userID).
		Where("teams.slug = ?", teamSlug).
		Count(&count).Error
	if err != nil {
		log.Printf("ERROR checking ownership for Ident %v, userID %v, teamSlug %v: %v", identID, userID, teamSlug, err)
		return false, err
	}

	return count > 0, nil
}

func UserIsInIdentsTeam(ctx context.Context, app AppContext, identID uint, userID uint, teamSlug string) (bool, error) {
	var count int64
	err := app.Database().WithContext(ctx).
		Model(&models.Ident{}).
		Joins("JOIN targets ON targets.id = idents.target_id").
		Joins("JOIN teams ON teams.id = targets.team_id").
		Joins("JOIN users_teams ON users_teams.team_id = teams.id").
		Where("idents.id = ?", identID).
		Where("users_teams.user_id = ?", userID).
		Where("teams.slug = ?", teamSlug).
		Count(&count).Error
	if err != nil {
		log.Printf("ERROR checking team membership for Ident %v, userID %v, teamSlug %v: %v", identID, userID, teamSlug, err)
		return false, err
	}

	return count > 0, nil
}

func DeleteIdent(ctx context.Context, app AppContext, ident models.Ident) error {
	_, err := gorm.G[models.Ident](app.Database()).Where("id = ?", ident.ID).Delete(ctx)
	if err != nil {
		log.Printf("ERROR deleting Ident with id %v from DB: %v", ident.ID, err)
		return err
	}

	log.Printf("Deleted Ident with id %v from DB", ident.ID)
	return nil
}

func UpdateIdentKey(ctx context.Context, app AppContext, identID uint, key string) error {
	return app.Database().WithContext(ctx).
		Model(&models.Ident{}).
		Where("id = ?", identID).
		Update("image_s3_key", key).
		Error
}

package db

import (
	"context"
	"identeam/models"
	"log"

	"gorm.io/gorm"
)

func CreateTeam(ctx context.Context, db *gorm.DB, team models.Team) (*models.Team, error) {
	err := gorm.G[models.Team](db).
		Create(ctx, &team)
	if err != nil {
		log.Printf("ERROR creating team %v in DB: %v", team, err)
		return nil, err
	}

	log.Printf("Created team with slug %v in DB", team.Slug)
	return &team, nil
}

func AddUserToTeam(ctx context.Context, db *gorm.DB, userID string, teamSlug string) (*models.Team, error) {
	user, err := GetUserById(ctx, db, userID)
	if err != nil {
		return &models.Team{}, err
	}

	var team models.Team
	if err := db.Where("slug = ?", teamSlug).First(&team).Error; err != nil {
		return &models.Team{}, err
	}

	err = db.Model(&user).
		Association("Teams").
		Append(&team)
	if err != nil {
		return &models.Team{}, err
	}

	return &team, nil
}

func RemoveUserFromTeam(ctx context.Context, db *gorm.DB, userID string, teamSlug string) (*models.Team, error) {
	user, err := GetUserById(ctx, db, userID)
	if err != nil {
		return &models.Team{}, err
	}

	var team models.Team
	if err := db.Where("slug = ?", teamSlug).First(&team).Error; err != nil {
		return &models.Team{}, err
	}

	// GORM does not throw error when association does not exist
	err = db.Model(&user).
		Association("Teams").
		Delete(&team)
	if err != nil {
		return &models.Team{}, err
	}

	return &team, nil
}

func GetTeamMembers(ctx context.Context, db *gorm.DB, userID string, teamSlug string) ([]*models.User, error) {
	var team models.Team
	if err := db.
		// TODO wieder ohne selbst, sobald debugged
		// Preload("Users", "user_id <> ?", userID).
		Preload("Users").
		Preload("Users.DeviceTokens").
		Where("slug = ? ", teamSlug). // not userID himself
		First(&team).Error; err != nil {
		return []*models.User{}, err
	}

	return team.Users, nil
}

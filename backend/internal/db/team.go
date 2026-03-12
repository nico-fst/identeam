package db

import (
	"context"
	"errors"
	"identeam/models"
	"log"
	"strings"

	"gorm.io/gorm"
)

func EnsureDefaultTeams(ctx context.Context, db *gorm.DB) error {
	defaultTeams := []models.Team{
		{
			Name:    "Die Kanten",
			Slug:    "die-kanten",
			Details: "Hier sind Kanten drin",
		},
		{
			Name:    "Wir4",
			Slug:    "wir4",
			Details: "Hier sind wir vier drin",
		},
	}

	for _, team := range defaultTeams {
		var existing models.Team

		err := db.Where("slug = ?", team.Slug).First(&existing).Error
		if err == nil {
			continue
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		if _, err := CreateTeam(ctx, db, team); err != nil {
			return err
		}
	}

	return nil
}

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

func GetTeamBySlug(ctx context.Context, db *gorm.DB, slug string) (*models.Team, error) {
	var team models.Team
	err := db.Model(&models.Team{}).
		Where("slug = ?", strings.ToLower(slug)).
		First(&team).Error
	if err != nil {
		log.Printf("ERROR looking up team with slug %v", slug)
		return nil, err
	}

	return &team, nil
}

func GetTeamMembers(ctx context.Context, db *gorm.DB, userID string, teamSlug string) ([]*models.User, error) {
	var team models.Team
	if err := db.
		Preload("Users", "user_id <> ?", userID).
		Preload("Users.DeviceTokens").
		Where("slug = ? ", teamSlug). // not userID himself
		First(&team).Error; err != nil {
		return []*models.User{}, err
	}

	return team.Users, nil
}

package db

import (
	"context"
	"errors"
	"fmt"
	"identeam/internal/apns"
	"identeam/models"
	"log"
	"strings"

	"gorm.io/gorm"
)

func stringPtr(s string) *string {
	return &s
}

func EnsureDefaultTeams(ctx context.Context, db *gorm.DB) error {
	defaultTeams := []models.Team{
		{
			Name:                 "Die Kanten",
			Slug:                 "die-kanten",
			Details:              "Hier sind Kanten drin",
			NotificationTemplate: stringPtr("OMG {{name}} ist mies am Gym hitten 🔥"),
		},
		{
			Name:                 "Wir4",
			Slug:                 "wir4",
			Details:              "Hier sind wir vier drin",
			NotificationTemplate: stringPtr("WOW {{name}} hat einen neuen Ident erstellt"),
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
		Preload("Users").
		Preload("Users.DeviceTokens").
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

func NotifyTeamMembers(ctx context.Context, db *gorm.DB, provider *apns.Provider, user models.User, slug string, alert models.Alert) ([]models.User, error) {
	team, err := GetTeamBySlug(ctx, db, slug)
	if err != nil {
		return nil, err
	}
	members := DerefUsers(team.Users)

	notification := models.NotificationPayload{
		APS: models.APS{
			Alert: alert,
		},
	}

	err = provider.NotifyUsers(members, notification)
	if err != nil {
		return nil, err
	}

	return members, nil
}

func NotifyTeamMembersAboutNewIdent(ctx context.Context, db *gorm.DB, provider *apns.Provider, ident models.Ident) ([]models.User, error) {
	var target models.UserWeeklyTarget
	err := db.Model(&models.UserWeeklyTarget{}).
		Preload("User").
		Preload("Team").
		First(&target, ident.UserWeeklyTargetID).Error
	if err != nil {
		return nil, err
	}

	teamWeek, err := GetTeamWeek(ctx, db, target.Team.Slug, target.TimeStart)
	if err != nil {
		return nil, err
	}

	notificationTemplate := "New Ident from {{name}} 🔥"
	if target.Team.NotificationTemplate != nil {
		notificationTemplate = *target.Team.NotificationTemplate
	}

	alert := models.Alert{
		Title:    fmt.Sprintf("🔥 [%d/%d] @ %v 🔥", teamWeek.IdentSum, teamWeek.TargetSum, target.Team.Name),
		Subtitle: strings.ReplaceAll(notificationTemplate, "{{name}}", target.User.FullName),
		Body:     ident.UserText,
	}

	members, err := NotifyTeamMembers(ctx, db, provider, target.User, target.Team.Slug, alert)
	if err != nil {
		return nil, err
	}

	return members, nil
}

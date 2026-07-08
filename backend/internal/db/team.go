package db

import (
	"context"
	"errors"
	"fmt"
	"identeam/models"
	"log"
	"strings"
	"time"

	"gorm.io/gorm"
)

func stringPtr(s string) *string {
	return &s
}

func EnsureDefaultTeams(ctx context.Context, app AppContext) error {
	db := app.Database()
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

		if _, err := CreateTeam(ctx, app, team); err != nil {
			return err
		}
	}

	return nil
}

func CreateTeam(ctx context.Context, app AppContext, team models.Team) (*models.Team, error) {
	err := gorm.G[models.Team](app.Database()).
		Create(ctx, &team)
	if err != nil {
		log.Printf("ERROR creating team %v in DB: %v", team, err)
		return nil, err
	}

	log.Printf("Created team with slug %v in DB", team.Slug)
	return &team, nil
}

func AddUserToTeam(ctx context.Context, app AppContext, userID string, teamSlug string) (*models.Team, error) {
	db := app.Database()
	user, err := GetUserById(ctx, app, userID)
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

func RemoveUserFromTeam(ctx context.Context, app AppContext, userID string, teamSlug string) (*models.Team, error) {
	db := app.Database()
	user, err := GetUserById(ctx, app, userID)
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

func GetTeamBySlug(ctx context.Context, app AppContext, slug string) (*models.Team, error) {
	var team models.Team
	err := app.Database().Model(&models.Team{}).
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

func GetTeamMembers(ctx context.Context, app AppContext, userID uint, teamSlug string) ([]*models.User, error) {
	var team models.Team
	if err := app.Database().
		Preload("Users", "id <> ?", userID).
		Preload("Users.DeviceTokens").
		Where("slug = ? ", teamSlug). // not userID himself
		First(&team).Error; err != nil {
		return []*models.User{}, err
	}

	return team.Users, nil
}

func GetTeamWeek(ctx context.Context, app AppContext, teamSlug string, timeStart time.Time) (*models.TeamWeekResponse, error) {
	targets, err := GetTeamsWeekTargets(ctx, app, teamSlug, timeStart)
	if err != nil {
		return nil, err
	}

	resp := models.NewTeamWeekResponse(ctx, app.R2(), teamSlug, targets)
	return &resp, nil
}

func NotifyTeamMembers(ctx context.Context, app AppContext, slug string, alert models.Alert) ([]models.User, error) {
	team, err := GetTeamBySlug(ctx, app, slug)
	if err != nil {
		return nil, err
	}
	members := derefUsers(team.Users)

	notification := models.NotificationPayload{
		APS: models.APS{
			Alert: alert,
		},
	}

	err = app.APNS().NotifyUsers(members, notification)
	if err != nil {
		return nil, err
	}

	return members, nil
}

func NotifyTeamMembersAboutNewIdent(ctx context.Context, app AppContext, ident models.Ident) ([]models.User, error) {
	var target models.Target
	err := app.Database().Model(&models.Target{}).
		Preload("User").
		Preload("Team").
		First(&target, ident.TargetID).Error
	if err != nil {
		return nil, err
	}

	teamWeek, err := GetTeamWeek(ctx, app, target.Team.Slug, target.TimeStart)
	if err != nil {
		return nil, err
	}

	notificationTemplate := "New Ident from {{name}} 🔥"
	if target.Team.NotificationTemplate != nil {
		notificationTemplate = *target.Team.NotificationTemplate
	}

	alert := models.Alert{
		Title:    fmt.Sprintf("🔥 [%d/%d] @ %v 🔥", teamWeek.IdentSum, teamWeek.TargetSum, target.Team.Name),
		Subtitle: strings.ReplaceAll(notificationTemplate, "{{name}}", target.User.Nickname),
		Body:     target.User.Nickname + ": " + ident.UserText,
	}

	members, err := NotifyTeamMembers(ctx, app, target.Team.Slug, alert)
	if err != nil {
		return nil, err
	}

	return members, nil
}

func NotifyTeamMembersAboutNewComment(ctx context.Context, app AppContext, comment *models.Comment, authorID uint) ([]models.User, error) {
	team, err := GetTeamByIdent(ctx, app, comment.IdentID)
	if err != nil {
		return nil, err
	}

	memberPtrs, err := GetTeamMembers(ctx, app, authorID, team.Slug)
	members := derefUsers(memberPtrs)

	alert := models.Alert{
		Title:    team.Name,
		Subtitle: fmt.Sprintf("%v commented:", comment.User.Nickname),
		Body:     comment.Text,
	}

	_, err = NotifyTeamMembers(ctx, app, team.Slug, alert)
	if err != nil {
		return nil, err
	}

	return members, nil
}

func GetTeamByIdent(ctx context.Context, app AppContext, identID uint) (*models.Team, error) {
	ident, err := GetIdentById(ctx, app, identID)
	if err != nil {
		return nil, err
	}

	var target models.Target
	err = app.Database().Model(&models.Target{}).
		Preload("User").
		Preload("Team").
		First(&target, ident.TargetID).Error
	if err != nil {
		return nil, err
	}

	return &target.Team, nil
}

func NotifyTeamMembersAboutTargetSet(ctx context.Context, app AppContext, targetID uint) ([]models.User, error) {
	var target models.Target
	err := app.Database().Model(&models.Target{}).
		Preload("User").
		Preload("Team").
		First(&target, targetID).Error
	if err != nil {
		return nil, err
	}

	alert := models.Alert{
		Title: fmt.Sprintf("🔥 %v 🔥", target.Team.Name),
		Body:  fmt.Sprintf("%v set Target to %d", target.User.Nickname, target.TargetCount),
	}

	members, err := NotifyTeamMembers(ctx, app, target.Team.Slug, alert)
	if err != nil {
		return nil, err
	}

	return members, nil
}

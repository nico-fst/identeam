package db

import (
	"context"
	"identeam/models"
	"identeam/util"
	"log"
	"time"

	"gorm.io/gorm"
)

func CreateTarget(ctx context.Context, app AppContext, target models.Target) (*models.Target, error) {
	// ensure timeStart is start of week
	target.TimeStart = util.TimeToWeekStart(target.TimeStart)

	err := gorm.G[models.Target](app.Database()).
		Create(ctx, &target)
	if err != nil {
		log.Printf("ERROR creating Target %v in DB: %v", target, err)
		return nil, err
	}

	log.Printf("Created Target with id %v in DB", target.ID)
	return &target, nil
}

func UpdateTargetCount(ctx context.Context, app AppContext, targetID uint, newCount int) (*models.Target, error) {
	db := app.Database()
	var target models.Target
	if err := db.Where("id = ?", targetID).First(&target).Error; err != nil {
		return nil, err
	}

	updates := map[string]interface{}{
		"TargetCount": newCount,
	}

	if err := db.Model(&target).Updates(updates).Error; err != nil {
		return nil, err
	}

	var newTarget models.Target
	if err := db.Where("id = ?", targetID).First(&newTarget).Error; err != nil {
		return nil, err
	}
	return &newTarget, nil
}

func GetTargetByTimeUserTeam(ctx context.Context, app AppContext, time time.Time, userID uint, teamSlug string) (*models.Target, error) {
	var target models.Target
	err := app.Database().Model(&models.Target{}).
		Joins("Team").
		Where(`targets.time_start = ? 
				AND targets.user_id = ? 
				AND "Team"."slug" = ?`,
			util.TimeToWeekStart(time),
			userID,
			teamSlug,
		).
		First(&target).Error
	if err != nil {
		log.Printf("ERROR looking up Target by time %v, userID %v, teamSlug %v: %v", time, userID, teamSlug, err)
		return nil, err
	}

	return &target, nil
}

func GetTeamsWeekTargets(ctx context.Context, app AppContext, teamSlug string, timeStart time.Time) ([]models.Target, error) {
	var targets []models.Target
	err := app.Database().Model(&models.Target{}).
		Joins("Team").
		Preload("User").
		Preload("Idents").
		Preload("Idents.Comments.User").
		Where(`"Team"."slug" = ? AND targets.time_start = ?`, teamSlug, util.TimeToWeekStart(timeStart)).
		Find(&targets).Error
	if err != nil {
		log.Printf("ERROR looking up TeamsWeekTargets for slug %v in week of %v: %v", teamSlug, timeStart, err)
		return nil, err
	}

	return targets, nil
}

func GetTargetsByUserTeam(ctx context.Context, app AppContext, userID uint, teamID uint, timeStart time.Time) ([]models.Target, error) {
	targets, err := gorm.G[models.Target](app.Database()).
		Where("user_id = ? AND time_start = ? AND team_id = ?", userID, util.TimeToWeekStart(timeStart), teamID).
		Find(ctx)

	return targets, err
}

func GetTargetsLast21DaysByUserTeam(ctx context.Context, app AppContext, userID uint, teamID uint, timeStart time.Time) ([]models.Target, error) {
	targets := make([]models.Target, 0)

	last3Weeks := []time.Time{
		timeStart.AddDate(0, 0, -7),
		timeStart.AddDate(0, 0, -14),
		timeStart.AddDate(0, 0, -21),
	}

	for _, week := range last3Weeks {
		weekTargets, err := GetTargetsByUserTeam(ctx, app, userID, teamID, week)
		if err != nil {
			return []models.Target{}, err
		}
		targets = append(
			targets,
			weekTargets...,
		)
	}

	return targets, nil
}

func FilterTargetsByTeamID(targets []models.Target, teamID uint) []models.Target {
	filteredTargets := make([]models.Target, 0)

	for _, t := range targets {
		if t.TeamID == teamID {
			filteredTargets = append(filteredTargets, t)
		}
	}

	return filteredTargets
}

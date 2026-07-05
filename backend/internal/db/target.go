package db

import (
	"context"
	"identeam/models"
	"identeam/util"
	"log"
	"time"

	"gorm.io/gorm"
)

func CreateUserWeeklyTarget(ctx context.Context, app AppContext, target models.UserWeeklyTarget) (*models.UserWeeklyTarget, error) {
	// ensure timeStart is start of week
	target.TimeStart = util.TimeToWeekStart(target.TimeStart)

	err := gorm.G[models.UserWeeklyTarget](app.Database()).
		Create(ctx, &target)
	if err != nil {
		log.Printf("ERROR creating UserWeeklyTarget %v in DB: %v", target, err)
		return nil, err
	}

	log.Printf("Created UserWeeklyTarget with id %v in DB", target.ID)
	return &target, nil
}

func UpdateUserWeeklyTargetCount(ctx context.Context, app AppContext, targetID uint, newCount int) (*models.UserWeeklyTarget, error) {
	db := app.Database()
	var target models.UserWeeklyTarget
	if err := db.Where("id = ?", targetID).First(&target).Error; err != nil {
		return nil, err
	}

	updates := map[string]interface{}{
		"TargetCount": newCount,
	}

	if err := db.Model(&target).Updates(updates).Error; err != nil {
		return nil, err
	}

	var newTarget models.UserWeeklyTarget
	if err := db.Where("id = ?", targetID).First(&newTarget).Error; err != nil {
		return nil, err
	}
	return &newTarget, nil
}

func GetUserWeeklyTargetByTimeUserTeam(ctx context.Context, app AppContext, time time.Time, userID uint, teamSlug string) (*models.UserWeeklyTarget, error) {
	var target models.UserWeeklyTarget
	err := app.Database().Model(&models.UserWeeklyTarget{}).
		Joins("Team").
		Where(`user_weekly_targets.time_start = ? 
				AND user_weekly_targets.user_id = ? 
				AND "Team"."slug" = ?`,
			util.TimeToWeekStart(time),
			userID,
			teamSlug,
		).
		First(&target).Error
	if err != nil {
		log.Printf("ERROR looking up UserWeeklyTarget by time %v, userID %v, teamSlug %v: %v", time, userID, teamSlug, err)
		return nil, err
	}

	return &target, nil
}

func GetTeamsWeekTargets(ctx context.Context, app AppContext, teamSlug string, timeStart time.Time) ([]models.UserWeeklyTarget, error) {
	var targets []models.UserWeeklyTarget
	err := app.Database().Model(&models.UserWeeklyTarget{}).
		Joins("Team").
		Preload("User").
		Preload("Idents").
		Preload("Idents.Comments.User").
		Where(`"Team"."slug" = ? AND user_weekly_targets.time_start = ?`, teamSlug, util.TimeToWeekStart(timeStart)).
		Find(&targets).Error
	if err != nil {
		log.Printf("ERROR looking up TeamsWeekTargets for slug %v in week of %v: %v", teamSlug, timeStart, err)
		return nil, err
	}

	return targets, nil
}

func GetTargetsByUserTeam(ctx context.Context, app AppContext, userID uint, teamID uint, timeStart time.Time) ([]models.UserWeeklyTarget, error) {
	targets, err := gorm.G[models.UserWeeklyTarget](app.Database()).
		Where("user_id = ? AND time_start = ? AND team_id = ?", userID, util.TimeToWeekStart(timeStart), teamID).
		Find(ctx)

	return targets, err
}

func GetTargetsLast21DaysByUserTeam(ctx context.Context, app AppContext, userID uint, teamID uint, timeStart time.Time) ([]models.UserWeeklyTarget, error) {
	targets := make([]models.UserWeeklyTarget, 0)

	last3Weeks := []time.Time{
		timeStart.AddDate(0, 0, -7),
		timeStart.AddDate(0, 0, -14),
		timeStart.AddDate(0, 0, -21),
	}

	for _, week := range last3Weeks {
		weekTargets, err := GetTargetsByUserTeam(ctx, app, userID, teamID, week)
		if err != nil {
			return []models.UserWeeklyTarget{}, err
		}
		targets = append(
			targets,
			weekTargets...,
		)
	}

	return targets, nil
}

func FilterTargetsByTeamID(targets []models.UserWeeklyTarget, teamID uint) []models.UserWeeklyTarget {
	filteredTargets := make([]models.UserWeeklyTarget, 0)

	for _, t := range targets {
		if t.TeamID == teamID {
			filteredTargets = append(filteredTargets, t)
		}
	}

	return filteredTargets
}

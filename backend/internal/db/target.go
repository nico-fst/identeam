package db

import (
	"context"
	"identeam/models"
	"identeam/util"
	"log"
	"time"

	"gorm.io/gorm"
)

func CreateUserWeeklyTarget(ctx context.Context, db *gorm.DB, target models.UserWeeklyTarget) (*models.UserWeeklyTarget, error) {
	// ensure timeStart is start of week
	target.TimeStart = util.TimeToWeekStart(target.TimeStart)

	err := gorm.G[models.UserWeeklyTarget](db).
		Create(ctx, &target)
	if err != nil {
		log.Printf("ERROR creating UserWeeklyTarget %v in DB: %v", target, err)
		return nil, err
	}

	log.Printf("Created UserWeeklyTarget with id %v in DB", target.ID)
	return &target, nil
}

func GetUserWeeklyTargetByTimeUserTeam(ctx context.Context, db *gorm.DB, time time.Time, userID uint, teamSlug string) (*models.UserWeeklyTarget, error) {
	var target models.UserWeeklyTarget
	err := db.Model(&models.UserWeeklyTarget{}).
		Joins("Team").
		Where("user_weekly_targets.time_start = ? AND user_weekly_targets.user_id = ? AND Team.slug = ?", util.TimeToWeekStart(time), userID, teamSlug).
		First(&target).Error
	if err != nil {
		log.Printf("ERROR looking up UserWeeklyTarget by time %v, userID %v, teamSlug %v: %v", time, userID, teamSlug, err)
		return nil, err
	}

	return &target, nil
}

func GetTeamsWeekTargets(ctx context.Context, db *gorm.DB, teamSlug string, timeStart time.Time) ([]models.UserWeeklyTarget, error) {
	var targets []models.UserWeeklyTarget
	err := db.Model(&models.UserWeeklyTarget{}).
		Joins("Team").
		Preload("User").
		Preload("Idents").
		Where("team.slug = ? AND user_weekly_targets.time_start = ?", teamSlug, util.TimeToWeekStart(timeStart)).
		Find(&targets).Error
	if err != nil {
		log.Printf("ERROR looking up TeamsWeekTargets for slug %v in week of %v: %v", teamSlug, timeStart, err)
		return nil, db.Error
	}

	return targets, nil
}

func GetTeamWeek(ctx context.Context, db *gorm.DB, teamSlug string, timeStart time.Time) (*models.TeamWeekResponse, error) {
	targets, err := GetTeamsWeekTargets(ctx, db, teamSlug, timeStart)
	if err != nil {
		return nil, err
	}

	resp := models.NewTeamWeekResponse(teamSlug, targets)
	return &resp, nil
}

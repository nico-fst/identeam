package db

import (
	"context"
	"errors"
	"identeam/models"
	"identeam/util"
	"log"
	"time"

	"gorm.io/gorm"
)

func ReplaceTargetDays(ctx context.Context, app AppContext, target models.Target, days []time.Time) (*models.Target, error) {
	database := app.Database().WithContext(ctx)
	target.TargetDays = make([]models.TargetDay, 0, len(days))

	// ensure timeStart is start of week
	target.TimeStart = util.TimeToWeekStart(target.TimeStart)

	err := database.Transaction(func(tx *gorm.DB) error {
		err := tx.
			Where(
				"time_start = ? AND user_id = ? AND team_id = ?",
				target.TimeStart, target.UserID, target.TeamID,
			).First(&target).Error

		// create if new
		if errors.Is(err, gorm.ErrRecordNotFound) {
			if err := tx.Create(&target).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		}

		// delete old target days
		if err := tx.
			Where("target_id = ?", target.ID). // GORM set target.ID in .Create()
			Delete(&models.TargetDay{}).Error; err != nil {
			return err
		}

		targetDays := make([]models.TargetDay, 0, len(days))
		for _, date := range days {
			targetDays = append(targetDays, models.TargetDay{
				TargetID: target.ID,
				Date:     date,
			})
		}

		// create new target days
		if len(targetDays) > 0 {
			if err := tx.Create(&targetDays).Error; err != nil {
				return err
			}
		}

		return tx.
			Preload("TargetDays", func(db *gorm.DB) *gorm.DB {
				return db.Order("date ASC")
			}).
			First(&target, target.ID).Error
	})
	if err != nil {
		return nil, err
	}

	return &target, nil
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
		Preload("TargetDays", func(db *gorm.DB) *gorm.DB {
			return db.Order("date ASC")
		}).
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

	weeksOverlappingLast21Days := []time.Time{
		timeStart,
		timeStart.AddDate(0, 0, -7),
		timeStart.AddDate(0, 0, -14),
		timeStart.AddDate(0, 0, -21),
	}

	for _, week := range weeksOverlappingLast21Days {
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

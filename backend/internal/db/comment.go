package db

import (
	"context"
	"identeam/models"
	"log"

	"gorm.io/gorm"
)

func CreateComment(ctx context.Context, app AppContext, userID uint, identID uint, text string) (*models.Comment, error) {
	comment := models.Comment{
		Text:    text,
		IdentID: identID,
		UserID:  userID,
	}

	err := gorm.G[models.Comment](app.Database()).
		Create(ctx, &comment)
	if err != nil {
		log.Printf("ERROR creating Comment %v in DB: %v", comment, err)
		return nil, err
	}

	preloadedComment, err := GetCommentById(ctx, app, comment.ID)
	if err != nil {
		return nil, err
	}
	log.Printf("Created Comment with id %v in DB", comment.ID)
	return preloadedComment, nil
}

func GetCommentById(ctx context.Context, app AppContext, commentID uint) (*models.Comment, error) {
	var comment models.Comment
	err := app.Database().Model(&models.Comment{}).
		Preload("Ident").
		Preload("User").
		Where("id = ?", commentID).
		First(&comment).Error
	if err != nil {
		log.Printf("ERROR looking up Comment with id %v: %v", commentID, err)
		return nil, err
	}

	return &comment, nil
}

func UserOwnsCommentOnIdentInTeam(ctx context.Context, app AppContext, commentID uint, identID uint, userID uint, teamSlug string) (bool, error) {
	var count int64
	err := app.Database().WithContext(ctx).
		Model(&models.Comment{}).
		Joins("JOIN idents ON idents.id = comments.ident_id").
		Joins("JOIN user_weekly_targets ON user_weekly_targets.id = idents.user_weekly_target_id").
		Joins("JOIN teams ON teams.id = user_weekly_targets.team_id").
		Where("comments.id = ?", commentID).
		Where("comments.ident_id = ?", identID).
		Where("comments.user_id = ?", userID).
		Where("teams.slug = ?", teamSlug).
		Count(&count).Error
	if err != nil {
		log.Printf("ERROR checking ownership for Comment %v, Ident %v, userID %v, teamSlug %v: %v", commentID, identID, userID, teamSlug, err)
		return false, err
	}

	return count > 0, nil
}

func DeleteComment(ctx context.Context, app AppContext, comment models.Comment) error {
	_, err := gorm.G[models.Comment](app.Database()).Where("id = ?", comment.ID).Delete(ctx)
	if err != nil {
		log.Printf("ERROR deleting Comment with id %v from DB: %v", comment.ID, err)
		return err
	}

	log.Printf("Deleted Comment with id %v in DB", comment.ID)
	return nil
}

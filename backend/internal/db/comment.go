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
		log.Printf("ERROR looking up Ident with id %v: %v", commentID, err)
		return nil, err
	}

	return &comment, nil
}

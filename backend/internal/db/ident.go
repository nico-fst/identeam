package db

import (
	"context"
	"identeam/models"
	"log"

	"gorm.io/gorm"
)

func CreateIdent(ctx context.Context, db *gorm.DB, ident models.Ident) (*models.Ident, error) {
	err := gorm.G[models.Ident](db).
		Create(ctx, &ident)
	if err != nil {
		log.Printf("ERROR creating Ident %v in DB: %v", ident, err)
		return nil, err
	}

	log.Printf("Created Ident with id %v in DB", ident.ID)
	return &ident, nil
}

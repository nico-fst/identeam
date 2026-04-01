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

func GetIdentById(ctx context.Context, db *gorm.DB, identID uint) (*models.Ident, error) {
	var ident models.Ident
	err := db.Model(&models.Ident{}).
		Where("id = ?", identID).
		First(&ident).Error
	if err != nil {
		log.Printf("ERROR looking up Ident with id %v: %v", identID, err)
		return nil, err
	}

	return &ident, nil
}

func DeleteIdent(ctx context.Context, db *gorm.DB, ident models.Ident) error {
	_, err := gorm.G[models.Ident](db).Where("id = ?", ident.ID).Delete(ctx)
	if err != nil {
		log.Printf("ERROR deleting Ident with id %v from DB: %v", ident.ID, err)
		return err
	}

	log.Printf("Deleted Ident with id %v from DB", ident.ID)
	return nil
}
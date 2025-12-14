package db

import (
	"identeam/models"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func ConnectSqlite() (*gorm.DB, error) {
	db, err := gorm.Open(sqlite.Open("identeam.sqlite3"), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// no ctx := context.Background() - comes from r.Context()

	db.AutoMigrate(
		&models.User{},
		&models.DeviceToken{})

	return db, nil
}

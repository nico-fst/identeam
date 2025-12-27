package db

import (
	"fmt"
	"identeam/models"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func ConnectPostgres() (*gorm.DB, error) {
	host := os.Getenv("DB_HOST")
	port := os.Getenv("DB_PORT")
	user := os.Getenv("DB_USER")
	password := os.Getenv("DB_PASSWORD")
	dbname := os.Getenv("DB_NAME")

	dsn := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, user, password, dbname,
	)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	db.AutoMigrate(
		&models.User{},
		&models.DeviceToken{},
	)

	return db, nil
}

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

package db

import (
	"errors"
	"fmt"
	"identeam/internal/apns"
	"identeam/internal/media"
	"identeam/models"
	"os"
	"strings"

	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// Because of import cycle
type AppContext interface {
	Database() *gorm.DB
	R2() *media.R2Client
	APNS() *apns.Provider
}

type Services struct {
	DB           *gorm.DB
	R2Client     *media.R2Client
	APNSProvider *apns.Provider
}

func NewServices(db *gorm.DB) *Services {
	return &Services{DB: db}
}

func (s *Services) Database() *gorm.DB {
	return s.DB
}

func (s *Services) R2() *media.R2Client {
	return s.R2Client
}

func (s *Services) APNS() *apns.Provider {
	if s.APNSProvider != nil {
		return s.APNSProvider
	}
	return &apns.Provider{}
}

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

	AutoMigrateAllModels(db)

	return db, nil
}

func ConnectSqlite() (*gorm.DB, error) {
	db, err := gorm.Open(sqlite.Open("identeam.sqlite3"), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	// no ctx := context.Background() - comes from r.Context()

	AutoMigrateAllModels(db)

	return db, nil
}

func AutoMigrateAllModels(db *gorm.DB) {
	db.AutoMigrate(
		&models.User{},
		&models.DeviceToken{},
		&models.Team{},
		&models.UserWeeklyTarget{},
		&models.Ident{},
	)
}

func IsDuplicateKeyError(err error) bool {
	if err == nil {
		return false
	}

	if errors.Is(err, gorm.ErrDuplicatedKey) {
		return true
	}

	msg := strings.ToLower(err.Error())

	return strings.Contains(msg, "unique constraint failed") ||
		strings.Contains(msg, "duplicate key value violates unique constraint") ||
		strings.Contains(msg, "duplicated key not allowed") ||
		strings.Contains(msg, "error 1062")
}

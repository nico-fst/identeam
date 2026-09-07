package db

import (
	"errors"
	"fmt"
	"identeam/internal/apns"
	"identeam/internal/appclock"
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

	db, err := gorm.Open(postgres.Open(dsn), GormConfig())
	if err != nil {
		return nil, err
	}

	AutoMigrateAllModels(db)

	return db, nil
}

func ConnectSqlite() (*gorm.DB, error) {
	db, err := gorm.Open(sqlite.Open("identeam.sqlite3"), GormConfig())
	if err != nil {
		return nil, err
	}

	// no ctx := context.Background() - comes from r.Context()

	AutoMigrateAllModels(db)

	return db, nil
}

func GormConfig() *gorm.Config {
	return &gorm.Config{
		NowFunc: appclock.Now,
	}
}

func AutoMigrateAllModels(db *gorm.DB) {
	renameLegacyUserNicknameColumn(db)
	renameLegacyTargetsTable(db)
	renameLegacyIdentTargetColumn(db)

	db.AutoMigrate(
		&models.User{},
		&models.DeviceToken{},
		&models.Team{},
		&models.Target{},
		&models.TargetDay{},
		&models.Ident{},
		&models.Comment{},
	)
}

func renameLegacyUserNicknameColumn(db *gorm.DB) {
	if !db.Migrator().HasTable(&models.User{}) {
		return
	}
	if !db.Migrator().HasColumn("users", "full_name") || db.Migrator().HasColumn("users", "nickname") {
		return
	}

	if err := db.Exec("ALTER TABLE users RENAME COLUMN full_name TO nickname").Error; err != nil {
		fmt.Printf("ERROR renaming users.full_name to users.nickname: %v\n", err)
	}
}

func renameLegacyTargetsTable(db *gorm.DB) {
	if !db.Migrator().HasTable("user_weekly_targets") || db.Migrator().HasTable(&models.Target{}) {
		return
	}

	if err := db.Migrator().RenameTable("user_weekly_targets", &models.Target{}); err != nil {
		fmt.Printf("ERROR renaming user_weekly_targets to targets: %v\n", err)
	}
}

func renameLegacyIdentTargetColumn(db *gorm.DB) {
	if !db.Migrator().HasTable(&models.Ident{}) {
		return
	}
	if !hasTableColumn(db, "idents", "user_weekly_target_id") || hasTableColumn(db, "idents", "target_id") {
		return
	}

	if err := db.Exec("ALTER TABLE idents RENAME COLUMN user_weekly_target_id TO target_id").Error; err != nil {
		fmt.Printf("ERROR renaming idents.user_weekly_target_id to idents.target_id: %v\n", err)
	}
}

func hasTableColumn(db *gorm.DB, tableName string, columnName string) bool {
	columns, err := db.Migrator().ColumnTypes(tableName)
	if err != nil {
		return false
	}

	for _, column := range columns {
		if column.Name() == columnName {
			return true
		}
	}

	return false
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

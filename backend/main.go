package main

import (
	"identeam/api"
	"identeam/internal/apns"
	dbpkg "identeam/internal/db"
	"log"
	"os"
	"strings"

	"github.com/joho/godotenv"
	"gorm.io/gorm"
)

// Run (implicitly build): go run main.go
// Build only: go build -o identeam && ./identeam
func main() {
	log.Println("Setting up server...")

	// Local: use .env file
	err := godotenv.Load(".env")
	if err != nil {
		log.Println("No .env found - env values should be set from outside (okay and normal in container => adapt docker-compose")
		log.Println(err)
	}
	log.Println("Loaded .env")

	// Setup DB
	db := &gorm.DB{}
	if strings.ToLower(os.Getenv("USE_INTERNAL_DB")) == "true" {
		log.Println("Connecting identeam.sqlite3...")
		db, err = dbpkg.ConnectSqlite()
	} else {
		log.Println("Connecting Postgres DB...")
		db, err = dbpkg.ConnectPostgres()
	}
	if err != nil {
		log.Fatal(err)
	}

	app := api.App{
		Provider: apns.Provider{
			KeyId:   os.Getenv("APNS_KEY_ID"),
			TeamId:  os.Getenv("TEAM_ID"),
			KeyFile: "./apns_key.p8",
			Topic:   os.Getenv("BUNDLE_ID"),
			Client:  nil,
			IsProd: strings.ToLower(os.Getenv("IS_PROD")) == "true",
		},
		DB:     db,
	}

	app.SetupServer()
}

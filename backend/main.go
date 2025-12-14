package main

import (
	"identeam/api"
	"identeam/internal/apns"
	"identeam/internal/db"
	"log"
	"os"

	"github.com/joho/godotenv"
)

// Run (implicitly build): go run main.go
// Build only: go build -o identeam && ./identeam
func main() {
	log.Println("Setting up server...")

	err := godotenv.Load(".env")
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Loaded .env")

	db, err := db.ConnectSqlite()
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Connected identeam.sqlite3")

	app := api.App{
		Provider: apns.Provider{
			KeyId:   os.Getenv("APNS_KEY_ID"),
			TeamId:  os.Getenv("TEAM_ID"),
			KeyFile: "./apns_key.p8",
			Topic:   os.Getenv("BUNDLE_ID"),
			Client:  nil,
		},
		DB: db,
	}

	app.SetupServer()
}

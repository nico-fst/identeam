package main

import (
	"identeam/api"
	"identeam/internal/apns"
	"identeam/internal/auth"
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

	auth.NewAuth()

	app := api.App{
		Provider: apns.Provider{
			KeyId:   os.Getenv("APNS_KEY_ID"),
			TeamId:  os.Getenv("TEAM_ID"),
			KeyFile: "./apns_key.p8",
			Topic:   os.Getenv("BUNDLE_ID"),
			Client:  nil,
		},
	}

	app.SetupServer()
}

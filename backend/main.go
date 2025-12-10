package main

import (
	"identeam/api"
	"identeam/internal"
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

	app := api.App{
		Provider: internal.Provider{
			KeyId:   os.Getenv("KEY_ID"),
			TeamId:  os.Getenv("TEAM_ID"),
			KeyFile: "./auth-key.p8",
			Topic:   os.Getenv("BUNDLE_ID"),
			Client:  nil,
		},
	}

	app.SetupServer()
}

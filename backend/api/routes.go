package api

import (
	"fmt"
	"identeam/internal"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
)

type App struct {
	Provider internal.Provider
}

func (app *App) SetupRoutes() http.Handler {
	mux := chi.NewRouter()

	mux.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"https://*", "http://*"},
		AllowedMethods:   []string{"GET"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	mux.Get("/trigger/{deviceToken}", app.SendNotification)

	return mux
}

func (app *App) SetupServer() {
	server := &http.Server{
		Addr:    fmt.Sprintf(":%s", "8080"),
		Handler: app.SetupRoutes(),
	}

	app.Provider = *app.Provider.SetupProvider()

	err := server.ListenAndServe()
	if err != nil {
		log.Println(err)
	}
}

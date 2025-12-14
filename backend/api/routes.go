package api

import (
	"fmt"
	"identeam/internal/apns"
	"identeam/middleware"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"gorm.io/gorm"
)

type App struct {
	Provider apns.Provider
	DB       *gorm.DB
}

func (app *App) SetupRoutes() http.Handler {
	mux := chi.NewRouter()

	mux.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"https://*", "http://*"},
		AllowedMethods:   []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link", "Set-Cookie"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	mux.Get("/trigger/{deviceToken}", app.SendNotification)

	// Native iOS Flow
	mux.Post("/auth/apple/native/callback", app.AuthCallbackNative)

	mux.Route("/", func(r chi.Router) {
		r.Use(middleware.JWTAuth,
			middleware.InjectUser(app.DB))

		r.Post("/auth/apple/check_session", app.CheckSession)
		r.Post("/auth/update_device_token", app.UpdateDeviceToken)
	})

	return mux
}

func (app *App) SetupServer() {
	server := &http.Server{
		Addr:    fmt.Sprintf(":%s", "8080"),
		Handler: app.SetupRoutes(),
	}

	app.Provider = *app.Provider.SetupProvider()

	log.Println("Starting server on 8080...")
	err := server.ListenAndServe()
	if err != nil {
		log.Println(err)
	}
}

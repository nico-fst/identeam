package api

import (
	"fmt"
	"identeam/docs"
	"identeam/internal/apns"
	"identeam/middleware"
	"log"
	"net/http"
	"os/exec"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"gorm.io/gorm"

	httpSwagger "github.com/swaggo/http-swagger"
)

type App struct {
	Provider apns.Provider
	DB       *gorm.DB
}

func initSwagger() {
	// resolved *Delim Error with: https://github.com/swaggo/swag/issues/1568

	cmd := exec.Command("go", "run", "github.com/swaggo/swag/cmd/swag@latest", "init")
	output, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Failed to generate swagger docs: %v\nOutput: %s", err, string(output))
		return
	}
	log.Println("Swagger docs generated successfully")

	docs.SwaggerInfo.BasePath = "/"
}

func (app *App) SetupRoutes() http.Handler {
	initSwagger()

	mux := chi.NewRouter()

	mux.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"https://*", "http://*"},
		AllowedMethods:   []string{"GET", "POST", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link", "Set-Cookie"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	mux.Mount("/swagger", httpSwagger.WrapHandler)

	mux.Get("/trigger/{deviceToken}", app.SendNotification)

	// Native iOS Flow
	mux.Post("/auth/apple/native/callback", app.AuthCallbackNative)

	mux.Route("/", func(r chi.Router) {
		r.Use(middleware.JWTAuth,
			middleware.InjectUser(app.DB))

		r.Get("/auth/apple/check_session", app.CheckSession)
		r.Post("/token/update_device_token", app.UpdateDeviceToken)
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

package api

import (
	"context"
	"fmt"
	"identeam/internal/apns"
	"identeam/internal/db"
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
		log.Printf("ERROR generating swagger docs: %v\nOutput: %s", err, string(output))
		return
	}
	log.Println("Swagger docs generated successfully")
}

func (app *App) SetupRoutes() http.Handler {
	return app.setupRoutes(true)
}

func (app *App) SetupRoutesWithoutSwagger() http.Handler {
	return app.setupRoutes(false)
}

func (app *App) setupRoutes(enableSwagger bool) http.Handler {
	if enableSwagger {
		initSwagger()
	}

	mux := chi.NewRouter()

	mux.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"https://*", "http://*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link", "Set-Cookie"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	if enableSwagger {
		mux.Get("/swagger/doc.json", func(w http.ResponseWriter, r *http.Request) {
			http.ServeFile(w, r, "./docs/swagger.json")
		})
		mux.Mount("/swagger", httpSwagger.Handler(
			httpSwagger.URL("/swagger/doc.json"),
		))
	}

	mux.Get("/notify/{deviceToken}", app.SendNotification)

	mux.Post("/auth/password/login", app.LoginPassword)
	mux.Post("/auth/password/signup", app.SignupPassword)
	mux.Post("/auth/apple/native/callback", app.AuthCallbackNative) // Native iOS Flow

	mux.Route("/", func(r chi.Router) {
		r.Use(middleware.JWTAuth,
			middleware.InjectUser(app.DB))

		r.Get("/auth/apple/check_session", app.CheckSession)

		r.Post("/token/update_device_token", app.UpdateDeviceToken)

		r.Post("/me/update_user", app.UpdateUser) // PUT sobald Wrapper in Swift

		r.Get("/teams/me", app.GetMyTeams)
		r.Post("/teams/create", app.CreateTeam)
		r.Post("/teams/{slug}/join", app.JoinTeam)
		r.Post("/teams/{slug}/leave", app.LeaveTeam)
		r.Get("/teams/{slug}/week/{dateStart}", app.GetTeamWeek)
		r.Put("/teams/{slug}/targets/{dateStart}", app.PutUserTarget)
		
		r.Post("/idents/create", app.CreateIdent) // TODO auch {dateStart} mit 2006-01-01 date format
		r.Put("/idents/create", app.CreateIdent)
		r.Delete("/idents/{id}", app.DeleteIdent)

		r.Post("/notify/team/{slug}", app.NotifyTeam)
	})

	return mux
}

func (app *App) SetupDB() {
	err := db.EnsureDefaultTeams(context.Background(), app.DB)
	if err != nil {
		log.Fatalf("ERROR ensuring default teams: %v", err)
	}
}

func (app *App) SetupServer() {
	server := &http.Server{
		Addr:    fmt.Sprintf(":%s", "8080"),
		Handler: app.SetupRoutes(),
	}

	app.Provider = *app.Provider.SetupProvider()
	app.SetupDB()

	log.Println("Starting server on 8080...")
	err := server.ListenAndServe()
	if err != nil {
		log.Fatalf("ERROR starting server: %v", err)
	}
}

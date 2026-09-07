package api

import (
	"context"
	"fmt"
	"identeam/internal/apns"
	"identeam/internal/db"
	"identeam/internal/media"
	"identeam/middleware"
	"identeam/util"
	"log"
	"net/http"
	"os/exec"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
	"gorm.io/gorm"

	httpSwagger "github.com/swaggo/http-swagger"
)

type App struct {
	Now          func() time.Time // Optional clock for deterministic request tests.
	ApnsProvider apns.Provider
	DB           *gorm.DB
	R2Client     *media.R2Client
}

func (app *App) Database() *gorm.DB {
	return app.DB
}

func (app *App) R2() *media.R2Client {
	return app.R2Client
}

func (app *App) APNS() *apns.Provider {
	return &app.ApnsProvider
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
			middleware.InjectUser(app))

		r.Get("/auth/apple/check_session", app.CheckSession)

		r.Post("/token/update_device_token", app.UpdateDeviceToken)

		r.Get("/me", app.GetMe)
		r.Post("/me/avatar/get_upload_url", app.GetAvatarUploadURL)
		r.Post("/me/avatar/commit", app.CommitAvatarPayload)
		r.Post("/me/update_user", app.UpdateUser) // PUT sobald Wrapper in Swift

		r.Get("/teams/me", app.GetMyTeams)

		r.Post("/teams/create", app.CreateTeam)
		r.Post("/teams/{slug}/join", app.JoinTeam)
		r.Post("/teams/{slug}/leave", app.LeaveTeam)
		r.Post("/teams/{slug}/remind", app.RemindTeam)

		r.Get("/teams/{slug}/week/{dateStart}", app.GetTeamWeek)
		r.Get("/teams/{slug}/week/notifications", app.GetLocalNotificationsForWeek)

		r.Put("/teams/{slug}/targets/{dateStart}", app.PutTarget)
		r.Post("/teams/{slug}/idents/create", app.CreateIdent) // TODO auch {dateStart} mit 2006-01-01 date format
		r.Post("/teams/{slug}/idents/{id}/comment", app.CommentIdent)
		r.Delete("/teams/{slug}/idents/{id}/uncomment/{commentID}", app.UncommentIdent)
		r.Post("/teams/{slug}/idents/{id}/image/get_upload_url", app.GetIdentImageUploadURL)
		r.Post("/teams/{slug}/idents/{id}/image/commit", app.CommitIdentImage)
		r.Delete("/teams/{slug}/idents/{id}", app.DeleteIdent)
	})

	return mux
}

func (app *App) SetupDB() {
	err := db.EnsureDefaultTeams(context.Background(), app)
	if err != nil {
		log.Fatalf("ERROR ensuring default teams: %v", err)
	}
}

func (app *App) SetupServer() {
	server := &http.Server{
		Addr:    fmt.Sprintf(":%s", "8080"),
		Handler: app.SetupRoutes(),
	}

	app.ApnsProvider = *app.ApnsProvider.SetupProvider()
	app.SetupDB()

	log.Println("Starting server on 8080...")
	err := server.ListenAndServe()
	if err != nil {
		log.Fatalf("ERROR starting server: %v", err)
	}
}

func (app *App) now() time.Time {
	if app.Now != nil {
		return app.Now()
	}
	return util.Now()
}

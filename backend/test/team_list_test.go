package test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"identeam/api"
	"identeam/internal/auth"
	"identeam/internal/db"
	"identeam/models"
)

func TestTeamListDoesNotIncludeSyntheticTeams(t *testing.T) {
	t.Setenv("SESSION_TOKEN_SECRET", "debug-team-test-secret")
	database, err := gorm.Open(sqlite.Open(filepath.Join(t.TempDir(), "debug.sqlite")), db.GormConfig())
	if err != nil {
		t.Fatal(err)
	}
	if err = db.AutoMigrateAllModels(database); err != nil {
		t.Fatal(err)
	}
	sqlDB, err := database.DB()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })
	user := models.User{UserID: "debug-owner", Email: "owner@example.com", Nickname: "Nico", Username: "debug-owner"}
	if err = database.Create(&user).Error; err != nil {
		t.Fatal(err)
	}
	app := api.App{DB: database}
	handler := app.SetupRoutesWithoutSwagger()
	token, err := auth.CreateSessionToken(user.UserID, user.Email)
	if err != nil {
		t.Fatal(err)
	}
	request := func(method, path string, authenticated bool) *httptest.ResponseRecorder {
		req := httptest.NewRequest(method, path, nil)
		if authenticated {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, req)
		return response
	}
	for _, path := range []string{"/teams/me", "/teams/__debug__/week/2026-10-12"} {
		if response := request(http.MethodGet, path, false); response.Code != http.StatusUnauthorized {
			t.Fatalf("unauthenticated %s: %d", path, response.Code)
		}
	}
	var teams struct {
		Data struct {
			Teams []models.TeamDTO `json:"teams"`
		} `json:"data"`
	}
	response := request(http.MethodGet, "/teams/me", true)
	if response.Code != http.StatusOK {
		t.Fatal(response.Body.String())
	}
	if err = json.Unmarshal(response.Body.Bytes(), &teams); err != nil {
		t.Fatal(err)
	}
	if len(teams.Data.Teams) != 0 {
		t.Fatalf("user without memberships must receive no teams, got %#v", teams.Data.Teams)
	}
	response = request(http.MethodGet, "/teams/__debug__/week/2026-10-12", true)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("nonexistent Debug team must use ordinary lookup, got %d: %s", response.Code, response.Body.String())
	}
}

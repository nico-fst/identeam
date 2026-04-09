package integration_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"identeam/api"
	dbpkg "identeam/internal/db"
	"identeam/models"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

type jsonResponseEnvelope struct {
	Error   bool            `json:"error"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data"`
}

type authResponseData struct {
	User         models.UserResponse `json:"user"`
	SessionToken string              `json:"sessionToken"`
	Created      bool                `json:"created"`
}

type addUserToTeamResponse struct {
	User models.UserResponse `json:"user"`
	Team models.TeamResponse `json:"team"`
}

type getMyTeamsResponse struct {
	Teams []models.TeamResponse `json:"teams"`
}

type teamWeekMemberResponse struct {
	User        models.UserResponse    `json:"user"`
	TargetCount uint                   `json:"targetCount"`
	Idents      []models.IdentResponse `json:"idents"`
}

type getTeamWeekResponse struct {
	Slug      string                   `json:"slug"`
	TargetSum uint                     `json:"targetSum"`
	IdentSum  uint                     `json:"identSum"`
	Members   []teamWeekMemberResponse `json:"members"`
}

func newFeatureTestApp(t *testing.T) *api.App {
	t.Helper()
	t.Setenv("SESSION_TOKEN_SECRET", "feature-test-secret")

	dbPath := filepath.Join(t.TempDir(), "identeam-test.sqlite")
	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{})
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}

	err = db.AutoMigrate(
		&models.User{},
		&models.DeviceToken{},
		&models.Team{},
		&models.UserWeeklyTarget{},
		&models.Ident{},
	)
	if err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	if err := dbpkg.EnsureDefaultTeams(context.Background(), db); err != nil {
		t.Fatalf("ensure default teams: %v", err)
	}

	return &api.App{DB: db}
}

func newFeatureTestServer(t *testing.T) *httptest.Server {
	t.Helper()
	app := newFeatureTestApp(t)
	return httptest.NewServer(app.SetupRoutesWithoutSwagger())
}

func doJSONRequest(t *testing.T, client *http.Client, method string, url string, body any, token string) *http.Response {
	t.Helper()

	var bodyReader *bytes.Reader
	if body == nil {
		bodyReader = bytes.NewReader(nil)
	} else {
		payload, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal request body: %v", err)
		}
		bodyReader = bytes.NewReader(payload)
	}

	req, err := http.NewRequest(method, url, bodyReader)
	if err != nil {
		t.Fatalf("new request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("do request %s %s: %v", method, url, err)
	}

	return resp
}

func decodeEnvelope(t *testing.T, resp *http.Response) jsonResponseEnvelope {
	t.Helper()
	defer resp.Body.Close()

	var envelope jsonResponseEnvelope
	if err := json.NewDecoder(resp.Body).Decode(&envelope); err != nil {
		t.Fatalf("decode json envelope: %v", err)
	}

	return envelope
}

func decodeData[T any](t *testing.T, envelope jsonResponseEnvelope) T {
	t.Helper()

	var data T
	if len(envelope.Data) == 0 {
		t.Fatalf("response data missing")
	}
	if err := json.Unmarshal(envelope.Data, &data); err != nil {
		t.Fatalf("decode response data: %v", err)
	}

	return data
}

func signupUser(t *testing.T, serverURL string, email string) authResponseData {
	t.Helper()

	resp := doJSONRequest(t, http.DefaultClient, http.MethodPost, serverURL+"/auth/password/signup", api.SignupPasswordPayload{
		Email:    email,
		Password: "supersafe-password",
		FullName: "Test User",
		Username: "tester",
	}, "")

	if resp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, resp)
		t.Fatalf("signup failed with status %d: %s", resp.StatusCode, envelope.Message)
	}

	envelope := decodeEnvelope(t, resp)
	if envelope.Error {
		t.Fatalf("signup returned error: %s", envelope.Message)
	}

	return decodeData[authResponseData](t, envelope)
}

func createTeam(t *testing.T, serverURL string, token string, name string) models.TeamResponse {
	t.Helper()

	resp := doJSONRequest(t, http.DefaultClient, http.MethodPost, serverURL+"/teams/create", api.AddTeamPayload{
		Name:    name,
		Details: "Flow-Test-Team",
	}, token)

	if resp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, resp)
		t.Fatalf("create team failed with status %d: %s", resp.StatusCode, envelope.Message)
	}

	envelope := decodeEnvelope(t, resp)
	if envelope.Error {
		t.Fatalf("create team returned error: %s", envelope.Message)
	}

	return decodeData[models.TeamResponse](t, envelope)
}

func TestFeatureFlow_SignupCheckSessionCreateTeamAndListTeams(t *testing.T) {
	server := newFeatureTestServer(t)
	defer server.Close()

	authData := signupUser(t, server.URL, "primary@example.com")

	checkResp := doJSONRequest(t, http.DefaultClient, http.MethodGet, server.URL+"/auth/apple/check_session", nil, authData.SessionToken)
	if checkResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, checkResp)
		t.Fatalf("check session failed with status %d: %s", checkResp.StatusCode, envelope.Message)
	}

	checkEnvelope := decodeEnvelope(t, checkResp)
	if checkEnvelope.Error {
		t.Fatalf("check session returned error: %s", checkEnvelope.Message)
	}

	team := createTeam(t, server.URL, authData.SessionToken, "Feature Flow Team")
	if team.Slug != "feature-flow-team" {
		t.Fatalf("unexpected team slug: %q", team.Slug)
	}

	myTeamsResp := doJSONRequest(t, http.DefaultClient, http.MethodGet, server.URL+"/teams/me", nil, authData.SessionToken)
	if myTeamsResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, myTeamsResp)
		t.Fatalf("get my teams failed with status %d: %s", myTeamsResp.StatusCode, envelope.Message)
	}

	envelope := decodeEnvelope(t, myTeamsResp)
	if envelope.Error {
		t.Fatalf("get my teams returned error: %s", envelope.Message)
	}

	data := decodeData[getMyTeamsResponse](t, envelope)
	if len(data.Teams) != 1 {
		t.Fatalf("expected exactly one team, got %d", len(data.Teams))
	}
	if data.Teams[0].Slug != team.Slug {
		t.Fatalf("expected listed team slug %q, got %q", team.Slug, data.Teams[0].Slug)
	}
}

func TestFeatureFlow_TeamJoinTargetIdentAndWeekOverview(t *testing.T) {
	server := newFeatureTestServer(t)
	defer server.Close()

	owner := signupUser(t, server.URL, "owner@example.com")
	member := signupUser(t, server.URL, "member@example.com")

	team := createTeam(t, server.URL, owner.SessionToken, "Weekly Builders")

	joinResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/join/"+team.Slug, nil, member.SessionToken)
	if joinResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, joinResp)
		t.Fatalf("join team failed with status %d: %s", joinResp.StatusCode, envelope.Message)
	}

	joinEnvelope := decodeEnvelope(t, joinResp)
	if joinEnvelope.Error {
		t.Fatalf("join team returned error: %s", joinEnvelope.Message)
	}

	joinData := decodeData[addUserToTeamResponse](t, joinEnvelope)
	if joinData.Team.Slug != team.Slug {
		t.Fatalf("expected joined team slug %q, got %q", team.Slug, joinData.Team.Slug)
	}
	if joinData.User.UserID != member.User.UserID {
		t.Fatalf("expected joined user %q, got %q", member.User.UserID, joinData.User.UserID)
	}

	weekDate := time.Date(2026, 4, 8, 12, 0, 0, 0, time.UTC)

	targetResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/targets/create", api.AddUserTargetPayload{
		TimeStart:   weekDate.Format("2006-01-02"),
		TeamSlug:    team.Slug,
		TargetCount: 3,
	}, owner.SessionToken)

	if targetResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, targetResp)
		t.Fatalf("create target failed with status %d: %s", targetResp.StatusCode, envelope.Message)
	}

	targetEnvelope := decodeEnvelope(t, targetResp)
	if targetEnvelope.Error {
		t.Fatalf("create target returned error: %s", targetEnvelope.Message)
	}

	targetData := decodeData[models.UserWeeklyTargetResponse](t, targetEnvelope)
	if targetData.TargetCount != 3 {
		t.Fatalf("expected target count 3, got %d", targetData.TargetCount)
	}

	identResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/idents/create", api.AddIdentPayload{
		Time:     weekDate.Format(time.RFC3339),
		TeamSlug: team.Slug,
		UserText: "Completed a meaningful weekly ident.",
	}, owner.SessionToken)

	if identResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, identResp)
		t.Fatalf("create ident failed with status %d: %s", identResp.StatusCode, envelope.Message)
	}

	identEnvelope := decodeEnvelope(t, identResp)
	if identEnvelope.Error {
		t.Fatalf("create ident returned error: %s", identEnvelope.Message)
	}

	identData := decodeData[models.IdentResponse](t, identEnvelope)
	if identData.UserText != "Completed a meaningful weekly ident." {
		t.Fatalf("unexpected ident userText: %q", identData.UserText)
	}

	weekURL := fmt.Sprintf("%s/teams/%s/week?date=%s", server.URL, team.Slug, weekDate.Format(time.RFC3339))
	weekResp := doJSONRequest(t, http.DefaultClient, http.MethodGet, weekURL, nil, owner.SessionToken)
	if weekResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, weekResp)
		t.Fatalf("get team week failed with status %d: %s", weekResp.StatusCode, envelope.Message)
	}

	weekEnvelope := decodeEnvelope(t, weekResp)
	if weekEnvelope.Error {
		t.Fatalf("get team week returned error: %s", weekEnvelope.Message)
	}

	weekData := decodeData[getTeamWeekResponse](t, weekEnvelope)
	if weekData.Slug != team.Slug {
		t.Fatalf("expected week slug %q, got %q", team.Slug, weekData.Slug)
	}
	if weekData.TargetSum != 3 {
		t.Fatalf("expected target sum 3, got %d", weekData.TargetSum)
	}
	if weekData.IdentSum != 1 {
		t.Fatalf("expected ident sum 1, got %d", weekData.IdentSum)
	}
	if len(weekData.Members) != 1 {
		t.Fatalf("expected one member with target activity, got %d", len(weekData.Members))
	}
	if len(weekData.Members[0].Idents) != 1 {
		t.Fatalf("expected one ident for active member, got %d", len(weekData.Members[0].Idents))
	}
}

func TestFeatureFlow_UpdateUserAndDeviceToken(t *testing.T) {
	server := newFeatureTestServer(t)
	defer server.Close()

	authData := signupUser(t, server.URL, "profile@example.com")

	updateUserResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/me/update_user", api.UpdateUserPayload{
		User: api.UpdateUserData{
			FullName: "Profile User",
			Username: "profile-updated",
		},
	}, authData.SessionToken)

	if updateUserResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, updateUserResp)
		t.Fatalf("update user failed with status %d: %s", updateUserResp.StatusCode, envelope.Message)
	}

	updateUserEnvelope := decodeEnvelope(t, updateUserResp)
	if updateUserEnvelope.Error {
		t.Fatalf("update user returned error: %s", updateUserEnvelope.Message)
	}

	updatedUser := decodeData[models.UserResponse](t, updateUserEnvelope)
	if updatedUser.Username != "profile-updated" {
		t.Fatalf("expected updated username %q, got %q", "profile-updated", updatedUser.Username)
	}

	updateTokenResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/token/update_device_token", api.UpdateDeviceTokenPayload{
		NewToken: "device-token-123",
		Platform: "ios",
	}, authData.SessionToken)

	if updateTokenResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, updateTokenResp)
		t.Fatalf("update device token failed with status %d: %s", updateTokenResp.StatusCode, envelope.Message)
	}

	updateTokenEnvelope := decodeEnvelope(t, updateTokenResp)
	if updateTokenEnvelope.Error {
		t.Fatalf("update device token returned error: %s", updateTokenEnvelope.Message)
	}

	deviceTokenUser := decodeData[models.UserResponse](t, updateTokenEnvelope)
	if deviceTokenUser.UserID != authData.User.UserID {
		t.Fatalf("expected device token update for user %q, got %q", authData.User.UserID, deviceTokenUser.UserID)
	}
}

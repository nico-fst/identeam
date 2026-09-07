package api_test

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"identeam/api"
	dbpkg "identeam/internal/db"
	"identeam/models"
	"identeam/util"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"reflect"
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
	User         models.UserDTO `json:"user"`
	SessionToken string         `json:"sessionToken"`
	Created      bool           `json:"created"`
}

type addUserToTeamDTO struct {
	User models.UserDTO `json:"user"`
	Team models.TeamDTO `json:"team"`
}

type getMyTeamsResponse struct {
	Teams []models.TeamDTO `json:"teams"`
}

type teamWeekMemberResponse struct {
	User       models.UserDTO `json:"user"`
	TargetDays []string       `json:"targetDays"`

	Idents []models.IdentDTO `json:"idents"`
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
	db, err := gorm.Open(sqlite.Open(dbPath), dbpkg.GormConfig())
	if err != nil {
		t.Fatalf("open sqlite db: %v", err)
	}

	err = db.AutoMigrate(
		&models.User{},
		&models.DeviceToken{},
		&models.Team{},
		&models.Target{},
		&models.TargetDay{},
		&models.Ident{},
		&models.Comment{},
	)
	if err != nil {
		t.Fatalf("automigrate: %v", err)
	}

	if err := dbpkg.EnsureDefaultTeams(context.Background(), dbpkg.NewServices(db)); err != nil {
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
		Nickname: "Test User",
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

func createTeam(t *testing.T, serverURL string, token string, name string) models.TeamDTO {
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

	return decodeData[models.TeamDTO](t, envelope)
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

	joinResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/join", nil, member.SessionToken)
	if joinResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, joinResp)
		t.Fatalf("join team failed with status %d: %s", joinResp.StatusCode, envelope.Message)
	}

	joinEnvelope := decodeEnvelope(t, joinResp)
	if joinEnvelope.Error {
		t.Fatalf("join team returned error: %s", joinEnvelope.Message)
	}

	joinData := decodeData[addUserToTeamDTO](t, joinEnvelope)
	if joinData.Team.Slug != team.Slug {
		t.Fatalf("expected joined team slug %q, got %q", team.Slug, joinData.Team.Slug)
	}
	if joinData.User.UserID != member.User.UserID {
		t.Fatalf("expected joined user %q, got %q", member.User.UserID, joinData.User.UserID)
	}

	weekDate := futureTargetWeek().AddDate(0, 0, 2).Add(12 * time.Hour)

	targetResp := doJSONRequest(t, http.DefaultClient, http.MethodPut, server.URL+"/teams/"+team.Slug+"/targets/"+weekDate.Format("2006-01-02"), api.PutTargetPayload{
		TargetDays: []string{futureTargetWeek().AddDate(0, 0, 0).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 4).Format("2006-01-02")},
	}, owner.SessionToken)

	if targetResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, targetResp)
		t.Fatalf("create target failed with status %d: %s", targetResp.StatusCode, envelope.Message)
	}

	targetEnvelope := decodeEnvelope(t, targetResp)
	if targetEnvelope.Error {
		t.Fatalf("create target returned error: %s", targetEnvelope.Message)
	}

	targetData := decodeData[models.TargetDTO](t, targetEnvelope)
	if !reflect.DeepEqual(targetData.TargetDays, []string{futureTargetWeek().AddDate(0, 0, 0).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 4).Format("2006-01-02")}) {
		t.Fatalf("unexpected target days: %#v", targetData.TargetDays)
	}

	identResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/idents/create", api.AddIdentPayload{
		Time:     weekDate.Format(time.RFC3339),
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

	identData := decodeData[models.IdentDTO](t, identEnvelope)
	if identData.ID == 0 {
		t.Fatal("expected created ident response to include id")
	}
	if identData.UserText != "Completed a meaningful weekly ident." {
		t.Fatalf("unexpected ident userText: %q", identData.UserText)
	}

	weekURL := fmt.Sprintf("%s/teams/%s/week/%s", server.URL, team.Slug, weekDate.Format("2006-01-02"))
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
	if len(weekData.Members[0].TargetDays) != 3 {
		t.Fatalf("expected derived target count 3, got %d", len(weekData.Members[0].TargetDays))
	}
	if !reflect.DeepEqual(weekData.Members[0].TargetDays, []string{futureTargetWeek().AddDate(0, 0, 0).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 4).Format("2006-01-02")}) {
		t.Fatalf("unexpected week target days: %#v", weekData.Members[0].TargetDays)
	}
	if len(weekData.Members[0].Idents) != 1 {
		t.Fatalf("expected one ident for active member, got %d", len(weekData.Members[0].Idents))
	}
}

func TestFeatureFlow_PutTargetRejectsInvalidDates(t *testing.T) {
	tests := []struct {
		name  string
		dates []string
	}{
		{name: "invalid format", dates: []string{"08.04.2026"}},
		{name: "duplicate", dates: []string{futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02")}},
		{name: "outside requested week", dates: []string{futureTargetWeek().AddDate(0, 0, 7).Format("2006-01-02")}},
		{name: "more than seven", dates: []string{
			futureTargetWeek().AddDate(0, 0, 0).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 1).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 3).Format("2006-01-02"),
			futureTargetWeek().AddDate(0, 0, 4).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 5).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 6).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 6).Format("2006-01-02"),
		}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			server := newFeatureTestServer(t)
			defer server.Close()

			owner := signupUser(t, server.URL, "target-validation@example.com")
			team := createTeam(t, server.URL, owner.SessionToken, "Target Validation Team")

			resp := doJSONRequest(
				t,
				http.DefaultClient,
				http.MethodPut,
				server.URL+"/teams/"+team.Slug+"/targets/"+futureTargetWeek().Format("2006-01-02"),
				api.PutTargetPayload{TargetDays: tt.dates},
				owner.SessionToken,
			)
			if resp.StatusCode != http.StatusBadRequest {
				envelope := decodeEnvelope(t, resp)
				t.Fatalf("expected status 400, got %d: %s", resp.StatusCode, envelope.Message)
			}
			decodeEnvelope(t, resp)
		})
	}
}

func TestFeatureFlow_CreateIdentSucceedsWithoutNotificationTemplate(t *testing.T) {
	server := newFeatureTestServer(t)
	defer server.Close()

	owner := signupUser(t, server.URL, "owner-no-template@example.com")
	team := createTeam(t, server.URL, owner.SessionToken, "No Template Team")

	weekDate := futureTargetWeek().AddDate(0, 0, 2).Add(12 * time.Hour)

	targetResp := doJSONRequest(t, http.DefaultClient, http.MethodPut, server.URL+"/teams/"+team.Slug+"/targets/"+weekDate.Format("2006-01-02"), api.PutTargetPayload{
		TargetDays: []string{futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02")},
	}, owner.SessionToken)
	if targetResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, targetResp)
		t.Fatalf("create target failed with status %d: %s", targetResp.StatusCode, envelope.Message)
	}

	targetEnvelope := decodeEnvelope(t, targetResp)
	if targetEnvelope.Error {
		t.Fatalf("create target returned error: %s", targetEnvelope.Message)
	}

	identResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/idents/create", api.AddIdentPayload{
		Time:     weekDate.Format(time.RFC3339),
		UserText: "This ident should not panic.",
	}, owner.SessionToken)

	if identResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, identResp)
		t.Fatalf("create ident failed with status %d: %s", identResp.StatusCode, envelope.Message)
	}

	identEnvelope := decodeEnvelope(t, identResp)
	if identEnvelope.Error {
		t.Fatalf("create ident returned error: %s", identEnvelope.Message)
	}

	identData := decodeData[models.IdentDTO](t, identEnvelope)
	if identData.UserText != "This ident should not panic." {
		t.Fatalf("unexpected ident userText: %q", identData.UserText)
	}
}

func TestFeatureFlow_DeleteIdentRequiresOwner(t *testing.T) {
	server := newFeatureTestServer(t)
	defer server.Close()

	owner := signupUser(t, server.URL, "delete-owner@example.com")
	member := signupUser(t, server.URL, "delete-member@example.com")
	team := createTeam(t, server.URL, owner.SessionToken, "Delete Ownership Team")

	joinResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/join", nil, member.SessionToken)
	if joinResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, joinResp)
		t.Fatalf("join team failed with status %d: %s", joinResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, joinResp)

	weekDate := futureTargetWeek().AddDate(0, 0, 2).Add(12 * time.Hour)
	targetResp := doJSONRequest(t, http.DefaultClient, http.MethodPut, server.URL+"/teams/"+team.Slug+"/targets/"+weekDate.Format("2006-01-02"), api.PutTargetPayload{
		TargetDays: []string{futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02")},
	}, owner.SessionToken)
	if targetResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, targetResp)
		t.Fatalf("create target failed with status %d: %s", targetResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, targetResp)

	identResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/idents/create", api.AddIdentPayload{
		Time:     weekDate.Format(time.RFC3339),
		UserText: "Only the owner can delete this.",
	}, owner.SessionToken)
	if identResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, identResp)
		t.Fatalf("create ident failed with status %d: %s", identResp.StatusCode, envelope.Message)
	}
	identEnvelope := decodeEnvelope(t, identResp)
	identData := decodeData[models.IdentDTO](t, identEnvelope)

	deleteURL := fmt.Sprintf("%s/teams/%s/idents/%d", server.URL, team.Slug, identData.ID)
	memberDeleteResp := doJSONRequest(t, http.DefaultClient, http.MethodDelete, deleteURL, nil, member.SessionToken)
	if memberDeleteResp.StatusCode != http.StatusForbidden {
		envelope := decodeEnvelope(t, memberDeleteResp)
		t.Fatalf("expected member delete to be forbidden, got status %d: %s", memberDeleteResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, memberDeleteResp)

	memberUploadResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, deleteURL+"/image/get_upload_url", models.PresignedRequestPayload{
		ContentType: "image/jpeg",
		SizeBytes:   1024,
	}, member.SessionToken)
	if memberUploadResp.StatusCode != http.StatusForbidden {
		envelope := decodeEnvelope(t, memberUploadResp)
		t.Fatalf("expected member upload url to be forbidden, got status %d: %s", memberUploadResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, memberUploadResp)

	memberCommitResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, deleteURL+"/image/commit", models.CommitUploadPayload{
		Key: fmt.Sprintf("teams/%s/idents/%d/image_v1.jpg", team.Slug, identData.ID),
	}, member.SessionToken)
	if memberCommitResp.StatusCode != http.StatusForbidden {
		envelope := decodeEnvelope(t, memberCommitResp)
		t.Fatalf("expected member image commit to be forbidden, got status %d: %s", memberCommitResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, memberCommitResp)

	ownerDeleteResp := doJSONRequest(t, http.DefaultClient, http.MethodDelete, deleteURL, nil, owner.SessionToken)
	if ownerDeleteResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, ownerDeleteResp)
		t.Fatalf("owner delete failed with status %d: %s", ownerDeleteResp.StatusCode, envelope.Message)
	}
	ownerDeleteEnvelope := decodeEnvelope(t, ownerDeleteResp)
	if ownerDeleteEnvelope.Error {
		t.Fatalf("owner delete returned error: %s", ownerDeleteEnvelope.Message)
	}
}

func TestFeatureFlow_DeleteCommentRequiresCommentAuthorAndMatchingIdent(t *testing.T) {
	server := newFeatureTestServer(t)
	defer server.Close()

	owner := signupUser(t, server.URL, "comment-delete-owner@example.com")
	member := signupUser(t, server.URL, "comment-delete-member@example.com")
	team := createTeam(t, server.URL, owner.SessionToken, "Comment Delete Team")

	joinResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/join", nil, member.SessionToken)
	if joinResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, joinResp)
		t.Fatalf("join team failed with status %d: %s", joinResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, joinResp)

	weekDate := futureTargetWeek().AddDate(0, 0, 2).Add(12 * time.Hour)
	targetResp := doJSONRequest(t, http.DefaultClient, http.MethodPut, server.URL+"/teams/"+team.Slug+"/targets/"+weekDate.Format("2006-01-02"), api.PutTargetPayload{
		TargetDays: []string{futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02")},
	}, owner.SessionToken)
	if targetResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, targetResp)
		t.Fatalf("create target failed with status %d: %s", targetResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, targetResp)

	identResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/idents/create", api.AddIdentPayload{
		Time:     weekDate.Format(time.RFC3339),
		UserText: "This ident will receive a comment.",
	}, owner.SessionToken)
	if identResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, identResp)
		t.Fatalf("create ident failed with status %d: %s", identResp.StatusCode, envelope.Message)
	}
	identEnvelope := decodeEnvelope(t, identResp)
	identData := decodeData[models.IdentDTO](t, identEnvelope)

	commentResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, fmt.Sprintf("%s/teams/%s/idents/%d/comment", server.URL, team.Slug, identData.ID), api.CommentIdentpayload{
		Text: "ship it",
	}, member.SessionToken)
	if commentResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, commentResp)
		t.Fatalf("create comment failed with status %d: %s", commentResp.StatusCode, envelope.Message)
	}
	commentEnvelope := decodeEnvelope(t, commentResp)
	commentData := decodeData[models.CommentDTO](t, commentEnvelope)
	if commentData.Text != "ship it" {
		t.Fatalf("expected comment text %q, got %q", "ship it", commentData.Text)
	}

	deleteURL := fmt.Sprintf("%s/teams/%s/idents/%d/uncomment/%d", server.URL, team.Slug, identData.ID, commentData.ID)
	ownerDeleteResp := doJSONRequest(t, http.DefaultClient, http.MethodDelete, deleteURL, nil, owner.SessionToken)
	if ownerDeleteResp.StatusCode != http.StatusForbidden {
		envelope := decodeEnvelope(t, ownerDeleteResp)
		t.Fatalf("expected owner delete to be forbidden, got status %d: %s", ownerDeleteResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, ownerDeleteResp)

	wrongIdentDeleteURL := fmt.Sprintf("%s/teams/%s/idents/%d/uncomment/%d", server.URL, team.Slug, identData.ID+1, commentData.ID)
	wrongIdentDeleteResp := doJSONRequest(t, http.DefaultClient, http.MethodDelete, wrongIdentDeleteURL, nil, member.SessionToken)
	if wrongIdentDeleteResp.StatusCode != http.StatusForbidden {
		envelope := decodeEnvelope(t, wrongIdentDeleteResp)
		t.Fatalf("expected wrong-ident delete to be forbidden, got status %d: %s", wrongIdentDeleteResp.StatusCode, envelope.Message)
	}
	decodeEnvelope(t, wrongIdentDeleteResp)

	memberDeleteResp := doJSONRequest(t, http.DefaultClient, http.MethodDelete, deleteURL, nil, member.SessionToken)
	if memberDeleteResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, memberDeleteResp)
		t.Fatalf("member delete failed with status %d: %s", memberDeleteResp.StatusCode, envelope.Message)
	}
	memberDeleteEnvelope := decodeEnvelope(t, memberDeleteResp)
	if memberDeleteEnvelope.Error {
		t.Fatalf("member delete returned error: %s", memberDeleteEnvelope.Message)
	}

	weekURL := fmt.Sprintf("%s/teams/%s/week/%s", server.URL, team.Slug, weekDate.Format("2006-01-02"))
	weekResp := doJSONRequest(t, http.DefaultClient, http.MethodGet, weekURL, nil, owner.SessionToken)
	if weekResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, weekResp)
		t.Fatalf("get team week failed with status %d: %s", weekResp.StatusCode, envelope.Message)
	}
	weekEnvelope := decodeEnvelope(t, weekResp)
	weekData := decodeData[getTeamWeekResponse](t, weekEnvelope)
	if len(weekData.Members) != 1 || len(weekData.Members[0].Idents) != 1 {
		t.Fatalf("expected one member with one ident, got %#v", weekData.Members)
	}
	if len(weekData.Members[0].Idents[0].Comments) != 0 {
		t.Fatalf("expected deleted comment to be absent, got %#v", weekData.Members[0].Idents[0].Comments)
	}
}

func TestFeatureFlow_GetTeamWeekAggregatesMultipleMembers(t *testing.T) {
	server := newFeatureTestServer(t)
	defer server.Close()

	owner := signupUser(t, server.URL, "teamweek-owner@example.com")
	member := signupUser(t, server.URL, "teamweek-member@example.com")
	team := createTeam(t, server.URL, owner.SessionToken, "Week Aggregate Team")
	joinResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/join", nil, member.SessionToken)
	if joinResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, joinResp)
		t.Fatalf("join team failed with status %d: %s", joinResp.StatusCode, envelope.Message)
	}

	joinEnvelope := decodeEnvelope(t, joinResp)
	if joinEnvelope.Error {
		t.Fatalf("join team returned error: %s", joinEnvelope.Message)
	}

	weekDate := futureTargetWeek().AddDate(0, 0, 2).Add(12 * time.Hour)

	ownerTargetResp := doJSONRequest(t, http.DefaultClient, http.MethodPut, server.URL+"/teams/"+team.Slug+"/targets/"+weekDate.Format("2006-01-02"), api.PutTargetPayload{
		TargetDays: []string{futureTargetWeek().AddDate(0, 0, 0).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 2).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 4).Format("2006-01-02")},
	}, owner.SessionToken)
	if ownerTargetResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, ownerTargetResp)
		t.Fatalf("create owner target failed with status %d: %s", ownerTargetResp.StatusCode, envelope.Message)
	}

	memberTargetResp := doJSONRequest(t, http.DefaultClient, http.MethodPut, server.URL+"/teams/"+team.Slug+"/targets/"+weekDate.Format("2006-01-02"), api.PutTargetPayload{
		TargetDays: []string{futureTargetWeek().AddDate(0, 0, 1).Format("2006-01-02"), futureTargetWeek().AddDate(0, 0, 3).Format("2006-01-02")},
	}, member.SessionToken)
	if memberTargetResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, memberTargetResp)
		t.Fatalf("create member target failed with status %d: %s", memberTargetResp.StatusCode, envelope.Message)
	}

	ownerIdentResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/idents/create", api.AddIdentPayload{
		Time:     weekDate.Format(time.RFC3339),
		UserText: "Owner ident one.",
	}, owner.SessionToken)
	if ownerIdentResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, ownerIdentResp)
		t.Fatalf("create owner ident failed with status %d: %s", ownerIdentResp.StatusCode, envelope.Message)
	}

	memberIdentResp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/idents/create", api.AddIdentPayload{
		Time:     weekDate.Add(time.Hour).Format(time.RFC3339),
		UserText: "Member ident one.",
	}, member.SessionToken)
	if memberIdentResp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, memberIdentResp)
		t.Fatalf("create member ident failed with status %d: %s", memberIdentResp.StatusCode, envelope.Message)
	}

	weekURL := fmt.Sprintf("%s/teams/%s/week/%s", server.URL, team.Slug, weekDate.Format("2006-01-02"))
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
	if weekData.TargetSum != 5 {
		t.Fatalf("expected target sum 5, got %d", weekData.TargetSum)
	}
	if weekData.IdentSum != 2 {
		t.Fatalf("expected ident sum 2, got %d", weekData.IdentSum)
	}
	if len(weekData.Members) != 2 {
		t.Fatalf("expected 2 members, got %d", len(weekData.Members))
	}
}

// Keep feature fixtures in a week that can legally be planned, regardless of run date.
func futureTargetWeek() time.Time {
	return util.TimeToWeekStart(util.Now()).AddDate(0, 0, 7)
}

func TestFeatureFlow_TargetsOnlyAllowFutureWeeksAfterMonday(t *testing.T) {
	app := newFeatureTestApp(t)
	app.Now = func() time.Time { return util.TimeToWeekStart(util.Now()).AddDate(0, 0, 1) }
	server := httptest.NewServer(app.SetupRoutesWithoutSwagger())
	defer server.Close()
	owner := signupUser(t, server.URL, "future-targets@example.com")
	team := createTeam(t, server.URL, owner.SessionToken, "Future Targets")
	currentWeek := util.TimeToWeekStart(util.Now())
	for _, tc := range []struct {
		name   string
		offset int
		status int
	}{
		{"past", -7, 400}, {"current Monday", 0, 400},
		{"current Sunday", 6, 400}, {"next Monday", 7, 200},
		{"next Sunday", 13, 200}, {"later week", 21, 200},
	} {
		t.Run(tc.name, func(t *testing.T) {
			day := currentWeek.AddDate(0, 0, tc.offset).Format("2006-01-02")
			resp := doJSONRequest(t, http.DefaultClient, http.MethodPut,
				server.URL+"/teams/"+team.Slug+"/targets/"+day,
				api.PutTargetPayload{TargetDays: []string{day}}, owner.SessionToken)
			envelope := decodeEnvelope(t, resp)
			if resp.StatusCode != tc.status {
				t.Fatalf("status %d, want %d: %s", resp.StatusCode, tc.status, envelope.Message)
			}
			if tc.status == 200 {
				got := decodeData[models.TargetDTO](t, envelope)
				if !got.TimeStart.Equal(util.TimeToWeekStart(currentWeek.AddDate(0, 0, tc.offset))) {
					t.Fatalf("wrong week: %v", got.TimeStart)
				}
				if !reflect.DeepEqual(got.TargetDays, []string{day}) {
					t.Fatalf("wrong replacement: %v", got.TargetDays)
				}
			}
		})
	}
	var count int64
	app.DB.Model(&models.Target{}).Where("time_start <= ?", currentWeek).Count(&count)
	if count != 0 {
		t.Fatalf("rejected requests persisted %d targets", count)
	}
}

func TestFeatureFlow_MondayPlanningAndUnplannedIdent(t *testing.T) {
	for _, tc := range []struct {
		name, now string
		monday    bool
	}{
		{"Monday start Berlin", "2026-09-06T22:00:00Z", true},
		{"Monday end Berlin", "2026-09-07T21:59:59Z", true},
		{"Tuesday start Berlin", "2026-09-07T22:00:00Z", false},
		{"Sunday", "2026-09-13T12:00:00Z", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			app := newFeatureTestApp(t)
			now, _ := time.Parse(time.RFC3339, tc.now)
			app.Now = func() time.Time { return now }
			server := httptest.NewServer(app.SetupRoutesWithoutSwagger())
			defer server.Close()
			owner := signupUser(t, server.URL, "monday-flow@example.com")
			team := createTeam(t, server.URL, owner.SessionToken, "Monday Flow")
			week := util.TimeToWeekStart(now)
			create := func(allow bool, when time.Time, want int) models.IdentDTO {
				t.Helper()
				resp := doJSONRequest(t, http.DefaultClient, http.MethodPost, server.URL+"/teams/"+team.Slug+"/idents/create",
					api.AddIdentPayload{Time: when.Format(time.RFC3339), UserText: "An ident", AllowWithoutTarget: allow}, owner.SessionToken)
				envelope := decodeEnvelope(t, resp)
				if resp.StatusCode != want {
					t.Fatalf("status %d, want %d: %s", resp.StatusCode, want, envelope.Message)
				}
				if want == 200 {
					return decodeData[models.IdentDTO](t, envelope)
				}
				return models.IdentDTO{}
			}
			create(false, now, 404)
			create(true, week.AddDate(0, 0, -1), 404)
			create(true, week.AddDate(0, 0, 7), 404)
			var count int64
			if err := app.DB.Model(&models.Target{}).Count(&count).Error; err != nil {
				t.Fatal(err)
			}
			if count != 0 {
				t.Fatal("unconfirmed requests must not create a target")
			}
			if tc.monday {
				create(true, now, 404)
			} else {
				first := create(true, now, 200)
				second := create(false, now, 200)
				if first.ID == second.ID {
					t.Fatal("expected two idents")
				}
				var targets []models.Target
				if err := app.DB.Preload("TargetDays").Preload("Idents").Find(&targets).Error; err != nil {
					t.Fatal(err)
				}
				if len(targets) != 1 || len(targets[0].TargetDays) != 0 || len(targets[0].Idents) != 2 {
					t.Fatalf("wrong unplanned target: %#v", targets)
				}
			}
			// Monday can still set or explicitly clear this week's plan.
			for _, days := range [][]string{{week.Format("2006-01-02"), week.AddDate(0, 0, 6).Format("2006-01-02")}, {}} {
				resp := doJSONRequest(t, http.DefaultClient, http.MethodPut, server.URL+"/teams/"+team.Slug+"/targets/"+week.Format("2006-01-02"), api.PutTargetPayload{TargetDays: days}, owner.SessionToken)
				envelope := decodeEnvelope(t, resp)
				want := 400
				if tc.monday {
					want = 200
				}
				if resp.StatusCode != want {
					t.Fatalf("planning status %d, want %d: %s", resp.StatusCode, want, envelope.Message)
				}
			}
			if tc.monday {
				create(false, now, 200)
			}
			resp := doJSONRequest(t, http.DefaultClient, http.MethodGet, server.URL+"/teams/"+team.Slug+"/week/"+week.Format("2006-01-02"), nil, owner.SessionToken)
			result := decodeData[getTeamWeekResponse](t, decodeEnvelope(t, resp))
			if result.TargetSum != 0 || result.IdentSum == 0 || len(result.Members) != 1 || len(result.Members[0].TargetDays) != 0 {
				t.Fatalf("wrong zero-target week: %#v", result)
			}
		})
	}
}

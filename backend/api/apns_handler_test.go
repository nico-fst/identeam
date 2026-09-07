package api_test

import (
	"identeam/models"
	"identeam/util"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestLocalNotificationSuggestionsAreEmptyWithoutIdentHistory(t *testing.T) {
	server := newFeatureTestServer(t)
	defer server.Close()

	user := signupUser(t, server.URL, "reminder-without-history@example.com")
	team := createTeam(t, server.URL, user.SessionToken, "Reminder Without History")

	resp := doJSONRequest(
		t,
		http.DefaultClient,
		http.MethodGet,
		server.URL+"/teams/"+team.Slug+"/week/notifications?dateStart="+futureTargetWeek().Format("2006-01-02"),
		nil,
		user.SessionToken,
	)
	if resp.StatusCode != http.StatusOK {
		envelope := decodeEnvelope(t, resp)
		t.Fatalf("expected status 200, got %d: %s", resp.StatusCode, envelope.Message)
	}

	envelope := decodeEnvelope(t, resp)
	if envelope.Error {
		t.Fatalf("expected successful response, got error: %s", envelope.Message)
	}

	reminders := decodeData[[]models.LocalNotificationDTO](t, envelope)
	if len(reminders) != 0 {
		t.Fatalf("expected no intelligent suggestions, got %d", len(reminders))
	}
}

func TestLocalNotificationSuggestionsUseRequestedWeek(t *testing.T) {
	app := newFeatureTestApp(t)
	server := httptest.NewServer(app.SetupRoutesWithoutSwagger())
	defer server.Close()
	user := signupUser(t, server.URL, "dated-reminders@example.com")
	team := createTeam(t, server.URL, user.SessionToken, "Dated Reminders")
	var dbUser models.User
	var dbTeam models.Team
	if err := app.DB.Where("user_id = ?", user.User.UserID).First(&dbUser).Error; err != nil {
		t.Fatal(err)
	}
	if err := app.DB.Where("slug = ?", team.Slug).First(&dbTeam).Error; err != nil {
		t.Fatal(err)
	}
	historyTime := util.Now().AddDate(0, 0, -1)
	target := models.Target{TimeStart: util.TimeToWeekStart(historyTime), UserID: dbUser.ID, TeamID: dbTeam.ID}
	if err := app.DB.Create(&target).Error; err != nil {
		t.Fatal(err)
	}
	if err := app.DB.Create(&models.Ident{TargetID: target.ID, Time: historyTime}).Error; err != nil {
		t.Fatal(err)
	}
	for _, week := range []time.Time{futureTargetWeek(), futureTargetWeek().AddDate(0, 0, 21), time.Date(2027, 3, 22, 0, 0, 0, 0, util.AppLocation())} {
		// A Wednesday also identifies the containing Monday-to-Sunday week.
		resp := doJSONRequest(t, http.DefaultClient, http.MethodGet, server.URL+"/teams/"+team.Slug+"/week/notifications?dateStart="+week.AddDate(0, 0, 2).Format("2006-01-02"), nil, user.SessionToken)
		envelope := decodeEnvelope(t, resp)
		if resp.StatusCode != 200 {
			t.Fatalf("status %d: %s", resp.StatusCode, envelope.Message)
		}
		reminders := decodeData[[]models.LocalNotificationDTO](t, envelope)
		if len(reminders) != 7 {
			t.Fatalf("got %d reminders", len(reminders))
		}
		for i, reminder := range reminders {
			if got, want := reminder.Date.In(util.AppLocation()).Format("2006-01-02"), week.AddDate(0, 0, i).Format("2006-01-02"); got != want {
				t.Fatalf("date %s, want %s", got, want)
			}
		}
	}
	for _, query := range []string{"", "?dateStart=invalid", "?dateStart=2026-02-30"} {
		resp := doJSONRequest(t, http.DefaultClient, http.MethodGet, server.URL+"/teams/"+team.Slug+"/week/notifications"+query, nil, user.SessionToken)
		decodeEnvelope(t, resp)
		if resp.StatusCode != 400 {
			t.Fatalf("query %q: status %d", query, resp.StatusCode)
		}
	}
}

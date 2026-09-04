package api_test

import (
	"identeam/models"
	"net/http"
	"testing"
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
		server.URL+"/teams/"+team.Slug+"/week/notifications",
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

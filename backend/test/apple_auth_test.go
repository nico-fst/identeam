package test

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"identeam/api"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

type appleTestTransport func(*http.Request) (*http.Response, error)

func (f appleTestTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestNativeAppleAuthErrorsReturnJSON(t *testing.T) {
	cases := []struct {
		name, payload, key, body      string
		missingConfig, transportError bool
		status                        int
		message                       string
	}{
		{name: "invalid JSON", payload: `{`, status: 400, message: "invalid JSON"},
		{name: "missing code", payload: `{}`, status: 400, message: "authorizationCode is required"},
		{name: "missing configuration", missingConfig: true, status: 500, message: "apple sign-in is not configured"},
		{name: "missing key", key: "missing", status: 500, message: "server key missing"},
		{name: "invalid key", key: "invalid", status: 500, message: "unable to configure Apple sign-in"},
		{name: "transport error", transportError: true, status: 502, message: "unable to contact Apple sign-in"},
		{name: "Apple rejects request", body: `{"error":"invalid_request"}`, status: 400, message: "apple sign-in failed: invalid_request"},
		{name: "Apple rejects code", body: `{"error":"invalid_grant"}`, status: 400, message: "apple sign-in failed: invalid_grant"},
		{name: "invalid upstream JSON", body: `not JSON`, status: 502, message: "unable to contact Apple sign-in"},
		{name: "missing ID token", body: `{}`, status: 502, message: "invalid Apple sign-in response"},
		{name: "missing subject", body: `{"id_token":"eyJhbGciOiJSUzI1NiJ9.eyJlbWFpbCI6ImFAdGVzdC5pbnZhbGlkIn0.signature"}`, status: 502, message: "invalid Apple sign-in response"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Chdir(t.TempDir())
			t.Setenv("TEAM_ID", "TESTTEAMID")
			t.Setenv("SIWA_CLIENT_ID_APP", "de.nicostern.identeam")
			t.Setenv("SIWA_KEY_ID", "TESTKEYID")
			if tc.missingConfig {
				t.Setenv("SIWA_CLIENT_ID_APP", "")
			}
			if tc.key != "missing" {
				data := []byte("invalid private key")
				if tc.key != "invalid" {
					key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
					if err != nil {
						t.Fatal(err)
					}
					der, err := x509.MarshalPKCS8PrivateKey(key)
					if err != nil {
						t.Fatal(err)
					}
					data = pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})
				}
				if err := os.WriteFile("siwa_key.p8", data, 0600); err != nil {
					t.Fatal(err)
				}
			}
			original := http.DefaultTransport
			t.Cleanup(func() { http.DefaultTransport = original })
			http.DefaultTransport = appleTestTransport(func(r *http.Request) (*http.Response, error) {
				if r.URL.Host != "appleid.apple.com" {
					t.Fatalf("unexpected request host: %s", r.URL.Host)
				}
				if err := r.ParseForm(); err != nil {
					t.Fatal(err)
				}
				if r.Form.Get("client_id") != "de.nicostern.identeam" || r.Form.Get("code") != "test-code" || r.Form.Get("grant_type") != "authorization_code" || r.Form.Get("client_secret") == "" {
					t.Fatal("Apple token request has missing or incorrect parameters")
				}
				if tc.transportError {
					return nil, errors.New("upstream unavailable")
				}
				return &http.Response{StatusCode: 400, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(tc.body))}, nil
			})
			payload := tc.payload
			if payload == "" {
				payload = `{"authorizationCode":"test-code"}`
			}
			recorder := httptest.NewRecorder()
			request := httptest.NewRequest(http.MethodPost, "/auth/apple/native/callback", strings.NewReader(payload))
			(&api.App{}).AuthCallbackNative(recorder, request)
			if recorder.Code != tc.status {
				t.Fatalf("status = %d, want %d; body = %s", recorder.Code, tc.status, recorder.Body.String())
			}
			if recorder.Header().Get("Content-Type") != "application/json" {
				t.Fatal("missing JSON content type")
			}
			var response struct {
				Error   bool   `json:"error"`
				Message string `json:"message"`
			}
			if err := json.Unmarshal(recorder.Body.Bytes(), &response); err != nil {
				t.Fatal(err)
			}
			if !response.Error || response.Message != tc.message {
				t.Fatalf("unexpected error envelope: %+v", response)
			}
		})
	}
}

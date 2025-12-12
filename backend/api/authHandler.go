package api

import (
	"context"
	"encoding/json"
	"fmt"
	"identeam/internal/auth"
	"identeam/util"
	"net/http"
	"os"

	"github.com/Timothylock/go-signin-with-apple/apple"
)

// Validates native SIWA
func (app *App) AuthCallbackNative(w http.ResponseWriter, r *http.Request) {
	// 1. Read body

	var payload struct {
		IdentityToken     string `json:"identityToken"`
		AuthorizationCode string `json:"authorizationCode"`
		UserID            string `json:"userID"`
		FullName          string `json:"fullName"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}
	if payload.AuthorizationCode == "" {
		http.Error(w, "authorizationCode is required", http.StatusBadRequest)
		return
	}

	// 2. SIWA generate ClientSecret

	teamID := os.Getenv("TEAM_ID")
	clientID := os.Getenv("SIWA_CLIENT_ID_APP")
	keyID := os.Getenv("SIWA_KEY_ID")

	keyBytes, err := os.ReadFile("./siwa_key.p8")
	if err != nil {
		http.Error(w, "Server key missing", http.StatusInternalServerError)
		return
	}
	keyString := string(keyBytes)

	// Generate the client secret used to authenticate with Apple's validation servers
	secret, err := apple.GenerateClientSecret(keyString, teamID, clientID, keyID)
	if err != nil {
		fmt.Println("error generating secret: " + err.Error())
		return
	}

	// 3. Validate AuthorizationCode against Apple's servers

	client := apple.New()
	vReq := apple.AppValidationTokenRequest{
		ClientID:     clientID,
		ClientSecret: secret,
		Code:         payload.AuthorizationCode,
	}
	var resp apple.ValidationResponse

	// Do the verification (send to Apple's Token endpoint)
	err = client.VerifyAppToken(context.Background(), vReq, &resp)
	if err != nil {
		fmt.Println("error verifying: " + err.Error())
		return
	}
	if resp.Error != "" {
		fmt.Printf("apple returned an error: %s - %s\n", resp.Error, resp.ErrorDescription)
		return
	}

	// 4. Extract Claims out of Apple's esp.IDToken (JWT))

	// Get the email
	// claims: *map[string]interface{} contains claims = content of JWT as Map
	claims, err := apple.GetClaims(resp.IDToken)
	if err != nil {
		fmt.Println("failed to get claims: " + err.Error())
		return
	}

	email, _ := (*claims)["email"].(string)
	sub, _ := (*claims)["sub"].(string) // Apple's unique stable UserID

	// 5. Create Session Token; respond

	sessionToken, err := auth.CreateSessionToken(sub, email)
	if err != nil {
		fmt.Println("failed to create session token:", err)
		http.Error(w, "Failed to create session token", http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Auth successful",
		Data: map[string]interface{}{
			"userID": sub,
			"email":  email,
			"sessionToken": sessionToken,
		},
	})
}
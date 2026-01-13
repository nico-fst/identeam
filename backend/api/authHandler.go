package api

import (
	"context"
	"encoding/json"
	"fmt"
	"identeam/internal/auth"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
	"os"

	"github.com/Timothylock/go-signin-with-apple/apple"
)

func (app *App) AuthClassic(w http.ResponseWriter, r *http.Request) {
	
}

// @Summary		Sign in with Apple (native)
// @Description	Validates the Apple Sign In authorization code, creates or retrieves a user, and returns a session token.
// @Tags			Auth
// @Accept			json
// @Produce		json
// @Param			payload	body		models.SignInPayload	true	"SignIn Payload"
// @Success		200		{object}	util.JSONResponse		"Returns the created/retrieved user, a session token and a boolean if the user is new"
// @Failure		400		{object}	util.JSONResponse		"Invalid JSON or missing authorizationCode"
// @Failure		500		{object}	util.JSONResponse		"Server error during user creation or session token generation"
// @Router			/auth/apple/native/callback [post]
func (app *App) AuthCallbackNative(w http.ResponseWriter, r *http.Request) {
	// Read body

	var payload models.SignInPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if payload.AuthorizationCode == "" {
		http.Error(w, "authorizationCode is required", http.StatusBadRequest)
		return
	}

	// SIWA: generate ClientSecret

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

	// Validate AuthorizationCode against Apple's servers

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

	// Extract Claims out of Apple's esp.IDToken (JWT)

	// Get the email
	// claims: *map[string]interface{} contains claims = content of JWT as Map
	claims, err := apple.GetClaims(resp.IDToken)
	if err != nil {
		fmt.Println("failed to get claims: " + err.Error())
		return
	}

	user := models.User{
		UserID:   (*claims)["sub"].(string), // Apple's unique stable UserID
		Email:    (*claims)["email"].(string),
		FullName: payload.FullName,
	}

	// Create or retrieve User; Return Session Token

	created, foundUser, err := db.GetElseCreateUser(r.Context(), app.DB, user)
	if err != nil {
		fmt.Println("failed to get (true)) or create (false) user:", foundUser, err)
		http.Error(w, "Failed to get or create user", http.StatusInternalServerError)
		return
	}

	sessionToken, err := auth.CreateSessionToken(user.UserID, user.Email)
	if err != nil {
		fmt.Println("failed to create session token:", err)
		http.Error(w, "Failed to create session token", http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Auth successful",
		Data: map[string]interface{}{
			"user": models.UserResponse{
				UserID:   foundUser.UserID,
				Email:    foundUser.Email,
				FullName: foundUser.FullName,
				Username: foundUser.Username,
			},
			"sessionToken": sessionToken,
			"created":      created,
		},
	})
}

// @Summary		Check Session
// @Description	Middleware tries authenticating user using its Bearer JWT
// @Tags			Auth
// @Accept			json
// @Produce		json
// @Success		200	{object}	util.JSONResponse
// @Router			/auth/apple/check_session [get]
func (app *App) CheckSession(w http.ResponseWriter, r *http.Request) {
	_, ok := middleware.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "SessionToken is valid",
		Data:    models.Empty{},
	})
}

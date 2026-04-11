package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"identeam/internal/auth"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"log"
	"net/http"
	"net/mail"
	"os"

	"github.com/Timothylock/go-signin-with-apple/apple"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type AuthResponseData struct {
	User         models.UserResponse `json:"user"`
	SessionToken string              `json:"sessionToken"`
	Created      bool                `json:"created"`
}

type LoginPasswordPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginPassword godoc
// @Summary		Login with email and password
// @Description	Authenticates a user with email/password and returns a session token.
// @Tags			Auth
// @Accept			json
// @Produce		json
// @Param			payload	body		LoginPasswordPayload	true	"Login payload"
// @Success		200		{object}	util.JSONResponse{data=AuthResponseData}
// @Failure		400		{object}	util.JSONResponse
// @Failure		404		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/auth/password/login [post]
func (app *App) LoginPassword(w http.ResponseWriter, r *http.Request) {
	var payload LoginPasswordPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errors.New("invalid JSON"), http.StatusBadRequest)
		return
	}
	if payload.Email == "" || payload.Password == "" {
		util.ErrorJSON(w, errors.New("email and password are required in body"), http.StatusBadRequest)
		return
	}
	if _, err := mail.ParseAddress(payload.Email); err != nil {
		util.ErrorJSON(w, errors.New("invalid email"), http.StatusBadRequest)
		return
	}

	user, err := db.GetUserByMail(r.Context(), app.DB, payload.Email)
	if err == gorm.ErrRecordNotFound {
		log.Printf("User with mail %v tried logging in but has to signup first", payload.Email)
		util.ErrorJSON(w, errors.New("no account found for this email - signup instead"), http.StatusNotFound)
		return
	}

	passwordMatches, user, err := db.DoesEmailMatchPassword(r.Context(), app.DB, payload.Email, payload.Password)
	if !passwordMatches {
		util.ErrorJSON(w, errors.New("did not find any user for combination of email and password"))
		return
	}
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	sessionToken, err := auth.CreateSessionToken(user.UserID, user.Email)
	if err != nil {
		fmt.Println("ERROR creating session token:", err)
		util.ErrorJSON(w, errors.New("ERROR creating session token"), http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Auth successful",
		Data: AuthResponseData{
			User:         user.ToDTO(),
			SessionToken: sessionToken,
			Created:      false,
		},
	})

}

type SignupPasswordPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	FullName string `json:"fullName"`
	Username string `json:"username"`
}

// SignupPassword godoc
// @Summary		Sign up with email and password
// @Description	Creates a password-based user account and returns a session token.
// @Tags			Auth
// @Accept			json
// @Produce		json
// @Param			payload	body		SignupPasswordPayload	true	"Signup payload"
// @Success		200		{object}	util.JSONResponse{data=AuthResponseData}
// @Failure		400		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/auth/password/signup [post]
func (app *App) SignupPassword(w http.ResponseWriter, r *http.Request) {
	var payload SignupPasswordPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errors.New("invalid JSON"), http.StatusBadRequest)
		return
	}
	if payload.Email == "" {
		util.ErrorJSON(w, errors.New("email is required for signup"), http.StatusBadRequest)
		return
	}

	passwordHash, err := bcrypt.GenerateFromPassword([]byte(payload.Password), 14)
	hashStr := string(passwordHash)
	if err != nil {
		util.ErrorJSON(w, errors.New("error hashing password"), http.StatusInternalServerError)
		return
	}

	user := models.User{
		UserID:       uuid.NewString(),
		Email:        payload.Email,
		AuthProvider: "password",
		PasswordHash: &hashStr,
		FullName:     payload.FullName,
		Username:     payload.Username,
	}

	foundUser, err := db.CreateUser(r.Context(), app.DB, user)
	if err != nil {
		fmt.Println("ERROR creating user:", foundUser, err)
		util.ErrorJSON(w, errors.New("ERROR creating user: "+err.Error()))
		return
	}

	sessionToken, err := auth.CreateSessionToken(user.UserID, user.Email)
	if err != nil {
		fmt.Println("ERROR creating session token:", err)
		util.ErrorJSON(w, errors.New("ERROR creating session token"), http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Auth successful",
		Data: AuthResponseData{
			User:         foundUser.ToDTO(),
			SessionToken: sessionToken,
			Created:      true,
		},
	})
}

type AuthApplePayload struct {
	IdentityToken     string `json:"identityToken"`
	AuthorizationCode string `json:"authorizationCode"`
	UserID            string `json:"userID"`
	FullName          string `json:"fullName"`
}

// @Summary		Sign in with Apple (native)
// @Description	Validates the Apple Sign In authorization code, creates or retrieves a user, and returns a session token.
// @Tags			Auth
// @Accept			json
// @Produce		json
// @Param			payload	body		AuthApplePayload	true	"SignIn Payload"
// @Success		200		{object}	util.JSONResponse{data=AuthResponseData}	"Returns the created/retrieved user, a session token and a boolean if the user is new"
// @Failure		400		{object}	util.JSONResponse					"Invalid JSON or missing authorizationCode"
// @Failure		500		{object}	util.JSONResponse					"Server error during user creation or session token generation"
// @Router			/auth/apple/native/callback [post]
func (app *App) AuthCallbackNative(w http.ResponseWriter, r *http.Request) {
	// Read body

	var payload AuthApplePayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errors.New("invalid JSON"), http.StatusBadRequest)
		return
	}
	if payload.AuthorizationCode == "" {
		util.ErrorJSON(w, errors.New("authorizationCode is required"), http.StatusBadRequest)
		return
	}

	// SIWA: generate ClientSecret

	teamID := os.Getenv("TEAM_ID")
	clientID := os.Getenv("SIWA_CLIENT_ID_APP")
	keyID := os.Getenv("SIWA_KEY_ID")

	keyBytes, err := os.ReadFile("./siwa_key.p8")
	if err != nil {
		util.ErrorJSON(w, errors.New("Server key missing"), http.StatusInternalServerError)
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
		fmt.Println("ERROR getting claims: " + err.Error())
		return
	}

	user := models.User{
		UserID:       (*claims)["sub"].(string), // Apple's unique stable UserID
		Email:        (*claims)["email"].(string),
		AuthProvider: "apple",
		FullName:     payload.FullName,
		// Username set afterwards updating User details
	}

	// Create or retrieve User; Return Session Token

	created, foundUser, err := db.GetElseCreateUser(r.Context(), app.DB, user)
	if err != nil {
		fmt.Println("ERROR getting (true)) or create (false) user:", foundUser, err)
		util.ErrorJSON(w, errors.New("ERROR getting or create user"), http.StatusInternalServerError)
		return
	}

	sessionToken, err := auth.CreateSessionToken(user.UserID, user.Email)
	if err != nil {
		fmt.Println("ERROR creating session token:", err)
		util.ErrorJSON(w, errors.New("ERROR creating session token"), http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Auth successful",
		Data: AuthResponseData{
			User:         foundUser.ToDTO(),
			SessionToken: sessionToken,
			Created:      created,
		},
	})
}

// @Summary		Check session
// @Description	Verifies that the Bearer session token is valid.
// @Tags			Auth
// @Produce		json
// @Security		BearerAuth
// @Success		200	{object}	util.JSONResponse{data=models.Empty}
// @Failure		401	{object}	util.JSONResponse
// @Router			/auth/apple/check_session [get]
func (app *App) CheckSession(w http.ResponseWriter, r *http.Request) {
	_, ok := middleware.GetUserIDFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errors.New("unable to retrieve userID from context"), http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "SessionToken is valid",
		Data:    models.Empty{},
	})
}

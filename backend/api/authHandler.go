package api

import (
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
	"strings"

	"github.com/Timothylock/go-signin-with-apple/apple"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type AuthResponseData struct {
	User         models.UserDTO `json:"user"`
	SessionToken string         `json:"sessionToken"`
	Created      bool           `json:"created"`
}

type LoginPasswordPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

// LoginPassword godoc
// @Summary		Login with email and password
// @Description	Authenticates a user with email/password and returns a session token. Returns 404 when no account exists for the email.
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

	_, err := db.GetUserByMail(r.Context(), app, payload.Email)
	if err == gorm.ErrRecordNotFound {
		log.Printf("User with mail %v tried logging in but has to signup first", payload.Email)
		util.ErrorJSON(w, errors.New("no account found for this email - signup instead"), http.StatusNotFound)
		return
	}

	passwordMatches, user, err := db.DoesEmailMatchPassword(r.Context(), app, payload.Email, payload.Password)
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
			User:         user.ToDTO(r.Context(), app.R2Client),
			SessionToken: sessionToken,
			Created:      false,
		},
	})

}

type SignupPasswordPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	Nickname string `json:"nickname"`
	Username string `json:"username"`
}

// SignupPassword godoc
// @Summary		Sign up with email and password
// @Description	Creates a password-based user account from email, password, optional nickname and username, then returns the created user plus a session token.
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
		Nickname:     payload.Nickname,
		Username:     payload.Username,
	}

	foundUser, err := db.CreateUser(r.Context(), app, user)
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
			User:         foundUser.ToDTO(r.Context(), app.R2Client),
			SessionToken: sessionToken,
			Created:      true,
		},
	})
}

type AuthApplePayload struct {
	IdentityToken     string `json:"identityToken"`
	AuthorizationCode string `json:"authorizationCode"`
	UserID            string `json:"userID"`
	Nickname          string `json:"nickname"`
}

// @Summary		Sign in with Apple (native)
// @Description	Exchanges the native Apple authorization code, creates or retrieves the user with the provided nickname, and returns a session token. Apple rejections are returned as JSON errors containing the Apple error code.
// @Tags			Auth
// @Accept			json
// @Produce		json
// @Param			payload	body		AuthApplePayload	true	"SignIn Payload"
// @Success		200		{object}	util.JSONResponse{data=AuthResponseData}	"Returns the created/retrieved user, a session token and a boolean if the user is new"
// @Failure		400		{object}	util.JSONResponse					"Invalid JSON, missing authorizationCode, or Apple rejected the authorization code"
// @Failure		500		{object}	util.JSONResponse					"Apple configuration or signing key invalid, user creation failure, or session token generation failure"
// @Failure		502		{object}	util.JSONResponse					"Apple unavailable or returned an invalid response"
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

	teamID := strings.TrimSpace(os.Getenv("TEAM_ID"))
	clientID := strings.TrimSpace(os.Getenv("SIWA_CLIENT_ID_APP"))
	keyID := strings.TrimSpace(os.Getenv("SIWA_KEY_ID"))
	if teamID == "" || clientID == "" || keyID == "" {
		log.Printf("Apple sign-in configuration missing: team_id=%t client_id=%t key_id=%t", teamID != "", clientID != "", keyID != "")
		util.ErrorJSON(w, errors.New("apple sign-in is not configured"), http.StatusInternalServerError)
		return
	}

	keyBytes, err := os.ReadFile("./siwa_key.p8")
	if err != nil {
		util.ErrorJSON(w, errors.New("server key missing"), http.StatusInternalServerError)
		return
	}
	keyString := string(keyBytes)

	// Generate the client secret used to authenticate with Apple's validation servers
	secret, err := apple.GenerateClientSecret(keyString, teamID, clientID, keyID)
	if err != nil {
		log.Printf("generate Apple client secret: %v", err)
		util.ErrorJSON(w, errors.New("unable to configure Apple sign-in"), http.StatusInternalServerError)
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
	err = client.VerifyAppToken(r.Context(), vReq, &resp)
	if err != nil {
		log.Printf("verify Apple authorization code: %v", err)
		util.ErrorJSON(w, errors.New("unable to contact Apple sign-in"), http.StatusBadGateway)
		return
	}
	if resp.Error != "" {
		log.Printf("Apple sign-in rejected: error=%q description=%q client_id=%q", resp.Error, resp.ErrorDescription, clientID)
		util.ErrorJSON(w, fmt.Errorf("apple sign-in failed: %s", resp.Error), http.StatusBadRequest)
		return
	}

	// Extract Claims out of Apple's esp.IDToken (JWT)

	// Get the email
	// claims: *map[string]interface{} contains claims = content of JWT as Map
	claims, err := apple.GetClaims(resp.IDToken)
	if err != nil {
		log.Printf("read Apple ID token claims: %v", err)
		util.ErrorJSON(w, errors.New("invalid Apple sign-in response"), http.StatusBadGateway)
		return
	}
	userID, hasUserID := (*claims)["sub"].(string)
	email, hasEmail := (*claims)["email"].(string)
	if !hasUserID || userID == "" || !hasEmail || email == "" {
		util.ErrorJSON(w, errors.New("invalid Apple sign-in response"), http.StatusBadGateway)
		return
	}

	user := models.User{
		UserID:       userID, // Apple's unique stable UserID
		Email:        email,
		AuthProvider: "apple",
		Nickname:     payload.Nickname,
		// Username set afterwards updating User details
	}

	// Create or retrieve User; Return Session Token

	created, foundUser, err := db.GetElseCreateUser(r.Context(), app, user)
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
			User:         foundUser.ToDTO(r.Context(), app.R2Client),
			SessionToken: sessionToken,
			Created:      created,
		},
	})
}

// @Summary		Check session
// @Description	Verifies that the Bearer session token is valid and the user can be resolved from the database.
// @Tags			Auth
// @Produce		json
// @Security		BearerAuth
// @Success		200	{object}	util.JSONResponse{data=models.Empty}
// @Failure		401	{object}	util.JSONResponse
// @Failure		500	{object}	util.JSONResponse
// @Router			/auth/apple/check_session [get]
func (app *App) CheckSession(w http.ResponseWriter, r *http.Request) {
	_, ok := middleware.GetUserIDFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "SessionToken is valid",
		Data:    models.Empty{},
	})
}

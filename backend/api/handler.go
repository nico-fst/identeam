package api

import (
	"bytes"
	"encoding/json"
	"identeam/util"
	"io"
	"log"
	"net/http"
	"net/url"

	"github.com/go-chi/chi/v5"
	"github.com/golang-jwt/jwt/v5"
	"github.com/markbates/goth/gothic"
)

func (app *App) SendNotification(w http.ResponseWriter, r *http.Request) {
	deviceToken := chi.URLParam(r, "deviceToken")

	res, err := app.Provider.SendNotification(deviceToken, "OMG das ist go nicht paris!")
	if err != nil {
		log.Fatal(err)
	}

	payload := util.JSONResponse{
		Error:   false,
		Message: "APNs call result",
		Data:    res.Sent(),
	}

	err = util.WriteJSON(w, http.StatusOK, payload)
	if err != nil {
		log.Println(err)
	}
}

func (app *App) Auth(w http.ResponseWriter, r *http.Request) {
	// Ensure provider param is set
	provider := chi.URLParam(r, "provider")
	if provider == "" {
		http.Error(w, "Provider is required", http.StatusBadRequest)
		return
	}

	// set query param for gothic
	// (need to do this as we don't use gorilla mux, to prevent error: "you must select a provider")
	q := r.URL.Query()
	q.Set("provider", provider)
	r.URL.RawQuery = q.Encode()

	// Gothic Auth:
	if gothUser, err := gothic.CompleteUserAuth(w, r); err == nil {
		// User already authenticated
		util.WriteJSON(w, http.StatusOK, gothUser)
	} else {
		// start Auth
		gothic.BeginAuthHandler(w, r)
	}
}

func (app *App) AuthCallback(w http.ResponseWriter, r *http.Request) {
	// read r body; restores it (readable only once)
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("AuthCallback: failed to read request body: %v", err)
		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return
	}
	r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

	values, err := url.ParseQuery(string(bodyBytes))
	if err != nil {
		log.Printf("AuthCallback: failed to parse request body: %v", err)
		http.Error(w, "Invalid request format", http.StatusBadRequest)
		return
	}

	// manually extract name since not provided by gothic.CompleteUserAuth
	var firstName, lastName string
	if rawUser := values.Get("user"); rawUser != "" {
		var userStruct struct {
			Email string `json:"email"`
			Name  struct {
				First string `json:"firstName"`
				Last  string `json:"lastName"`
			} `json:"name"`
		}
		if err := json.Unmarshal([]byte(rawUser), &userStruct); err != nil {
			log.Printf("AuthCallback: failed to unmarshal user JSON: %v", err)
			http.Error(w, "Invalid user JSON format", http.StatusBadRequest)
			return
		}
		firstName, lastName = userStruct.Name.First, userStruct.Name.Last
	}

	user, err := gothic.CompleteUserAuth(w, r)
	if err != nil {
		log.Printf("AuthCallback error: %v", err)
		http.Error(w, "Authentication failed: "+err.Error(), http.StatusUnauthorized)
		return
	}

	if user.Email == "" {
		log.Printf("AuthCallback: no email in user data")
		http.Error(w, "No user data returned from provider", http.StatusUnauthorized)
		return
	}

	if firstName != "" {
		user.FirstName = firstName
	}
	if lastName != "" {
		user.LastName = lastName
	}

	log.Printf("User authenticated (WebFlow) - UserID: %s, Email: %s Name: %s\n", user.UserID, user.Email, user.Name)
	http.Redirect(w, r, "http://localhost:5173", http.StatusFound)
}

func (app *App) AuthCallbackNative(w http.ResponseWriter, r *http.Request) {
	// Parse JSON body mit identityToken und userID
	var payload struct {
		IdentityToken string `json:"identityToken"`
		UserID        string `json:"userID"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		log.Printf("AuthCallbackNative: failed to decode JSON body: %v", err)
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	if payload.IdentityToken == "" {
		log.Printf("AuthCallbackNative: identityToken is empty")
		http.Error(w, "identityToken is required", http.StatusBadRequest)
		return
	}

	if payload.UserID == "" {
		log.Printf("AuthCallbackNative: userID is empty")
		http.Error(w, "userID is required", http.StatusBadRequest)
		return
	}

	// Decode JWT Token ohne Validierung (für jetzt)
	// TODO: In Production - Validiere gegen Apple's Public Keys
	claims := jwt.MapClaims{}
	token, err := jwt.ParseWithClaims(payload.IdentityToken, claims, func(token *jwt.Token) (interface{}, error) {
		// For now, accept token without validation
		return nil, nil
	})

	if err != nil && token == nil {
		log.Printf("AuthCallbackNative: warning - could not parse JWT token: %v", err)
		// Continue - wir haben userID, das ist ausreichend
	}

	// Extrahiere Daten aus Token Claims
	email, _ := claims["email"].(string)
	firstName, _ := claims["given_name"].(string)
	lastName, _ := claims["family_name"].(string)

	log.Printf("User authenticated natively - UserID: %s, Email: %s, Name: %s %s\n", payload.UserID, email, firstName, lastName)

	// TODO: Speichere User in DB oder generiere JWT Session
	response := util.JSONResponse{
		Error:   false,
		Message: "Authentication successful",
		Data: map[string]interface{}{
			"userID":    payload.UserID,
			"email":     email,
			"firstName": firstName,
			"lastName":  lastName,
			"provider":  "apple_native",
		},
	}

	util.WriteJSON(w, http.StatusOK, response)
}

func (app *App) Logout(w http.ResponseWriter, r *http.Request) {
	gothic.Logout(w, r)
	w.Header().Set("Location", "/")
	http.Redirect(w, r, "https://apple.com", http.StatusFound)
}

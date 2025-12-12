package api

import (
	"encoding/json"
	"identeam/internal/auth"
	"identeam/util"
	"net/http"
)

// Checks if Client's Session Token is (still) valid
func (app *App) CheckSession(w http.ResponseWriter, r *http.Request) {
	var payload struct {
		SessionToken string `json:"sessionToken"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	// Check Session Token
	sessionValid := false
	if payload.SessionToken != "" {
		if _, err := auth.VerifySessionToken(payload.SessionToken); err == nil {
			sessionValid = true
		}
	}

	response := struct {
		SessionValid bool `json:"sessionValid"`
	}{
		SessionValid: sessionValid,
	}

	if !sessionValid {
		util.WriteJSON(w, 401, util.JSONResponse{
			Error:   true,
			Message: "Invalid or expired tokens",
			Data:    response,
		})
	} else {
		util.WriteJSON(w, 200, util.JSONResponse{
			Error:   false,
			Message: "Session Token is valid",
			Data:    response,
		})
	}

}

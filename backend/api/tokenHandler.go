package api

import (
	"encoding/json"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
)

func (app *App) UpdateDeviceToken(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	var payload struct {
		NewToken string `json:"newToken"`
		Platform string `json:"platform"`
	}

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if payload.NewToken == "" || payload.Platform == "" {
		http.Error(w, "newToken and platform are required in body", http.StatusBadRequest)
		return
	}

	newToken := models.DeviceToken{
		Token:    payload.NewToken,
		Platform: payload.Platform,
	}

	updatedUser, err := db.UpdateUsersDeviceToken(r.Context(), app.DB, user, newToken)
	if err != nil {
		http.Error(w, "Error updating user", http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Updated DeviceToken successfully",
		Data:    updatedUser,
	})
}

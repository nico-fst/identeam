package api

import (
	"encoding/json"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
)

// @Summary		Update Device Token
// @Description	Updates the device token for the authenticated user. Used for push notifications.
// @Tags			Device
// @Accept			json
// @Produce		json
// @Param			payload	body		models.UpdateDeviceTokenPayload	true	"UpdateDeviceToken Payload"
// @Success		200		{object}	util.JSONResponse				"Returns the updated user info"
// @Failure		400		{object}	util.JSONResponse				"Invalid JSON or missing fields"
// @Failure		401		{object}	util.JSONResponse				"Unauthorized: user not found in context"
// @Failure		500		{object}	util.JSONResponse				"Server error updating the user"
// @Security		ApiKeyAuth
// @Router			/token/update_device_token [post]
func (app *App) UpdateDeviceToken(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	var payload models.UpdateDeviceTokenPayload
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
		http.Error(w, "Error updating DeviceToken", http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Updated DeviceToken successfully",
		Data: models.UserResponse{
			UserID:   updatedUser.UserID,
			Email:    updatedUser.Email,
			FullName: updatedUser.FullName,
			Username: updatedUser.Username,
		},
	})
}

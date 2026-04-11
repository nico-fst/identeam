package api

import (
	"encoding/json"
	"errors"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
)

type UpdateDeviceTokenPayload struct {
	NewToken string `json:"newToken"`
	Platform string `json:"platform"`
}

// UpdateDeviceToken godoc
// @Summary		Update device token
// @Description	Updates the device token for the authenticated user. Used for push notifications.
// @Tags			Device
// @Accept			json
// @Produce		json
// @Param			payload	body		UpdateDeviceTokenPayload	true	"UpdateDeviceToken payload"
// @Success		200		{object}	util.JSONResponse{data=models.UserResponse}
// @Failure		400		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Security		BearerAuth
// @Router			/token/update_device_token [post]
func (app *App) UpdateDeviceToken(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errors.New("unable to retrieve userID from context"), http.StatusInternalServerError)
		return
	}

	var payload UpdateDeviceTokenPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errors.New("invalid JSON"), http.StatusBadRequest)
		return
	}
	if payload.NewToken == "" || payload.Platform == "" {
		util.ErrorJSON(w, errors.New("newToken and platform are required in body"), http.StatusBadRequest)
		return
	}

	newToken := models.DeviceToken{
		Token:    payload.NewToken,
		Platform: payload.Platform,
	}

	updatedUser, err := db.UpdateUsersDeviceToken(r.Context(), app.DB, user, newToken)
	if err != nil {
		util.ErrorJSON(w, errors.New("Error updating DeviceToken"), http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Updated DeviceToken successfully",
		Data:    updatedUser.ToDTO(),
	})
}

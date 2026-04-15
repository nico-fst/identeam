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

type UpdateUserData struct {
	FullName string `json:"fullName"`
	Username string `json:"username"`
}

type UpdateUserPayload struct {
	User UpdateUserData `json:"user"`
}

// UpdateUser godoc
// @Summary		Update user information
// @Description	Updates the current user's full name and username from the nested user payload.
// @Tags			Users
// @Accept			json
// @Produce		json
// @Param			payload	body		UpdateUserPayload	true	"User update payload"
// @Success		200		{object}	util.JSONResponse{data=models.UserResponse}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		409		{object}	util.JSONResponse
// @Failure		422		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Security		BearerAuth
// @Router			/me/update_user [post]
func (app *App) UpdateUser(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errors.New("unable to retrieve userID from context"), http.StatusInternalServerError)
		return
	}

	var payload UpdateUserPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errors.New("invalid JSON"), http.StatusBadRequest)
		return
	}

	newUser, err := db.UpdateUserDetails(r.Context(), app.DB, user, models.User{
		UserID:   user.UserID,
		FullName: payload.User.FullName,
		Username: payload.User.Username,
	})
	if err != nil {
		switch err {
		case db.ErrFullNameTooLong:
			util.ErrorJSON(w, db.ErrFullNameTooLong, http.StatusUnprocessableEntity)
		case db.ErrUsernameTaken: // TODO not used since gorm triggers 'UNIQUE constraint failed' as general error before
			util.ErrorJSON(w, db.ErrUsernameTaken, http.StatusConflict)
		default:
			util.ErrorJSON(w, errors.New("Error saving user (username not available)"), http.StatusBadRequest)
		}
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Updated user details successfully",
		Data:    newUser.ToDTO(),
	})
}

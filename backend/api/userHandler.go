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

// UpdateUser godoc
// @Summary      Update user information
// @Description  Updates the current user's FullName and Username. FullName must be at most 10 characters.
// @Tags         users
// @Accept       json
// @Produce      json
// @Param        payload  body      models.UpdateUserPayload  true  "User update payload"
// @Success      200      {object}  models.UserResponse       "User updated successfully"
// @Failure      400      {string}  string                    "Invalid JSON"
// @Failure      422      {string}  string                    "fullname too long"
// @Failure      409      {string}  string                    "Username already taken"
// @Failure      500      {string}  string                    "Database or internal server error"
// @Security     ApiKeyAuth
// @Router       /user [put]
func (app *App) UpdateUser(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	var payload models.UpdateUserPayload

	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	newUser, err := db.UpdateUserDetails(r.Context(), app.DB, user, payload.User)
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
		Data: models.UserResponse{
			UserID:   newUser.UserID,
			Email:    newUser.Email,
			FullName: newUser.FullName,
			Username: newUser.Username,
		},
	})
}

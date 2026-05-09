package api

import (
	"errors"
	"fmt"
	"identeam/internal/db"
	"identeam/internal/media"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
	"strings"
	"time"
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
	user, payload, ok := userAndPayload[UpdateUserPayload](r.Context(), r.Body, w)
	if !ok {
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

type AvatarUploadURLPayload struct {
	ContentType string `json:"contentType"`
	SizeBytes   int    `json:"sizeBytes"`
}

func (app *App) GetAvatarUploadURL(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[AvatarUploadURLPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}

	if err := media.ValidateAvatar(payload.ContentType, payload.SizeBytes); err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	newKey, err := media.NextAvatarKey(user.UserID, user.AvatarS3Key, payload.ContentType)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	expiresAt := time.Now().Add(10 * time.Minute)

	uploadURL, err := app.Media.PresignPutObject(r.Context(), newKey, payload.ContentType, expiresAt)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Created avatar URL",
		Data: models.PresignedResponse{
			Key:          newKey,
			PresignedURL: uploadURL,
			ExpiresAt:    expiresAt,
		},
	})
}

type CommitAvatarPayload struct {
	Key string `json:"key"`
}

func (app *App) CommitAvatarPayload(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[CommitAvatarPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}

	// Guard: wrong | not existing key
	expectedPrefix := fmt.Sprintf("users/%s/profile/avatar_v", user.UserID)
	if !strings.HasPrefix(payload.Key, expectedPrefix) {
		util.ErrorJSON(w, errors.New("invalid profile image key"), http.StatusBadRequest)
		return
	}

	// Guard: not uploaded
	if err := app.Media.CheckExistence(r.Context(), payload.Key); err != nil {
		util.ErrorJSON(w, errors.New("uploaded profile image not found"), http.StatusBadRequest)
		return
	}

	if err := db.UpdateAvatarKey(r.Context(), app.DB, user.ID, payload.Key); err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Updated avatar",
		Data: models.CommitS3Response{
			Key: payload.Key,
		},
	})
}

type GetMeResponse struct {
	User   models.UserResponse      `json:"user"`
	Avatar *models.PresignedResponse `json:"avatar"`
}

func (app *App) GetMe(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	var avatar *models.PresignedResponse

	if user.AvatarS3Key != "" {
		expiresAt := time.Now().Add(10 * time.Minute)
		avatarURL, err := app.Media.PresignGetObject(r.Context(), user.AvatarS3Key, expiresAt)
		if err != nil {
			util.ErrorJSON(w, fmt.Errorf("could not get avatarURL: %v", err), http.StatusInternalServerError)
			return
		}

		avatar = &models.PresignedResponse{
			Key: user.AvatarS3Key,
			PresignedURL: avatarURL,
			ExpiresAt: expiresAt,
		}
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Your profile info",
		Data: GetMeResponse{
			User: user.ToDTO(),
			Avatar: avatar,
		},
	})
}

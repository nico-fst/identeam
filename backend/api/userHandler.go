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

	newUser, err := db.UpdateUserDetails(r.Context(), app, user, models.User{
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

// GetAvatarUploadURL godoc
// @Summary		Get avatar upload URL
// @Description	Creates a presigned PUT URL for uploading the authenticated user's avatar image.
// @Tags			Users
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			payload	body		models.PresignedRequestPayload	true	"Image upload request"
// @Success		200		{object}	util.JSONResponse{data=models.PresignedResponse}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/me/avatar/get_upload_url [post]
func (app *App) GetAvatarUploadURL(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[models.PresignedRequestPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}

	newKey, err := nextValidatedImageKey(payload, func(contentType string) (string, error) {
		return media.NextAvatarKey(user.UserID, user.AvatarS3Key, contentType)
	})
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	app.writePresignedUploadURL(w, r, mediaUploadTarget{
		Key:           newKey,
		ContentType:   payload.ContentType,
		ResponseLabel: "avatar",
	})
}

// CommitAvatarPayload godoc
// @Summary		Commit avatar upload
// @Description	Stores the uploaded avatar key on the authenticated user after validating the object exists.
// @Tags			Users
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			payload	body		models.CommitUploadPayload	true	"Committed upload key"
// @Success		200		{object}	util.JSONResponse{data=models.CommitS3Response}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/me/avatar/commit [post]
func (app *App) CommitAvatarPayload(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[models.CommitUploadPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}

	expectedPrefix := fmt.Sprintf("users/%s/profile/avatar_v", user.UserID)
	if !app.validateCommittedUpload(
		w,
		r,
		payload.Key,
		expectedPrefix,
		"invalid profile image key",
		"uploaded profile image not found",
	) {
		return
	}

	if err := db.UpdateAvatarKey(r.Context(), app, user.ID, payload.Key); err != nil {
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
	User   models.UserResponse       `json:"user"`
	Avatar *models.PresignedResponse `json:"avatar"`
}

// GetMe godoc
// @Summary		Get current user
// @Description	Returns the authenticated user's profile data and a presigned avatar URL when an avatar is set.
// @Tags			Users
// @Produce		json
// @Security		BearerAuth
// @Success		200	{object}	util.JSONResponse{data=GetMeResponse}
// @Failure		401	{object}	util.JSONResponse
// @Failure		500	{object}	util.JSONResponse
// @Router			/me [get]
func (app *App) GetMe(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	var avatar *models.PresignedResponse

	if user.AvatarS3Key != "" {
		expiresAt := time.Now().Add(10 * time.Minute)
		avatarURL, err := app.R2Client.PresignGetObject(r.Context(), user.AvatarS3Key, expiresAt)
		if err != nil {
			util.ErrorJSON(w, fmt.Errorf("could not get avatarURL: %v", err), http.StatusInternalServerError)
			return
		}

		avatar = &models.PresignedResponse{
			Key:          user.AvatarS3Key,
			PresignedURL: avatarURL,
			ExpiresAt:    expiresAt,
		}
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Your profile info",
		Data: GetMeResponse{
			User:   user.ToDTO(),
			Avatar: avatar,
		},
	})
}

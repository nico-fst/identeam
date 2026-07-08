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
	"strconv"

	"github.com/go-chi/chi/v5"
	"gorm.io/gorm"
)

type AddIdentPayload struct {
	TeamSlug string `json:"teamSlug,omitempty"`
	Time     string `json:"time"`
	UserText string `json:"userText"`
}

var (
	errTargetNotSet = errors.New("corresponding target not set (not found)")
)

// CreateIdent godoc
// @Summary		Create ident
// @Description	Creates an ident for the authenticated user in the team week identified by the path team slug and payload time, then notifies the team.
// @Tags			Idents
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string			true	"Team slug"
// @Param			payload	body		AddIdentPayload	true	"Ident payload"
// @Success		200		{object}	util.JSONResponse{data=models.IdentDTO}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		404		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/teams/{slug}/idents/create [post]
func (app *App) CreateIdent(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[AddIdentPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}
	slug := chi.URLParam(r, "slug")
	if slug == "" {
		slug = payload.TeamSlug
	}
	if slug == "" {
		util.ErrorJSON(w, errors.New("team slug is required"), http.StatusBadRequest)
		return
	}

	identTime, err := util.ParseRFC3339InAppLocation(payload.Time)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	target, err := db.GetUserWeeklyTargetByTimeUserTeam(r.Context(), app, identTime, user.ID, slug)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			util.ErrorJSON(w, errTargetNotSet, http.StatusNotFound)
		} else {
			util.ErrorJSON(w, err, http.StatusBadRequest)
		}
		return
	}

	newIdent := models.Ident{
		Time:               identTime,
		UserText:           payload.UserText,
		UserWeeklyTargetID: target.ID,
	}

	ident, err := db.CreateIdent(r.Context(), app, newIdent)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	// Notify team about new ident
	_, err = db.NotifyTeamMembersAboutNewIdent(r.Context(), app, *ident)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Created Ident, notified team successfully",
		Data:    ident.ToDTO(r.Context(), app.R2Client),
	})
}

// DeleteIdent godoc
// @Summary		Delete ident
// @Description	Deletes the authenticated user's ident identified by team slug and ident ID, then returns the deleted ident.
// @Tags			Idents
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string	true	"Team slug"
// @Param			id		path		int		true	"Ident ID"
// @Success		200		{object}	util.JSONResponse{data=models.IdentDTO}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		403		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/teams/{slug}/idents/{id} [delete]
func (app *App) DeleteIdent(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	identID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	slug := chi.URLParam(r, "slug")

	ident, err := db.GetIdentById(r.Context(), app, uint(identID))
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	ownsIdent, err := db.UserOwnsIdentInTeam(r.Context(), app, ident.ID, user.ID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	if !ownsIdent {
		util.ErrorJSON(w, errors.New("ident does not belong to user"), http.StatusForbidden)
		return
	}

	err = db.DeleteIdent(r.Context(), app, *ident)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Deleted Ident successfully",
		Data:    ident.ToDTO(r.Context(), app.R2Client),
	})
}

// GetIdentImageUploadURL godoc
// @Summary		Get ident image upload URL
// @Description	Creates a presigned PUT URL for uploading an image to the authenticated user's ident.
// @Tags			Idents
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string							true	"Team slug"
// @Param			id		path		int								true	"Ident ID"
// @Param			payload	body		models.PresignedRequestPayload	true	"Image upload request"
// @Success		200		{object}	util.JSONResponse{data=models.PresignedResponse}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		403		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/teams/{slug}/idents/{id}/image/get_upload_url [post]
func (app *App) GetIdentImageUploadURL(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[models.PresignedRequestPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}
	slug := chi.URLParam(r, "slug")
	identIDString := chi.URLParam(r, "id")
	identID64, err := strconv.ParseUint(identIDString, 10, 64)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}
	identID := uint(identID64)

	ident, err := db.GetIdentById(r.Context(), app, identID)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	ownsIdent, err := db.UserOwnsIdentInTeam(r.Context(), app, ident.ID, user.ID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	if !ownsIdent {
		util.ErrorJSON(w, errors.New("ident does not belong to user"), http.StatusForbidden)
		return
	}

	newKey, err := nextValidatedImageKey(payload, func(contentType string) (string, error) {
		return media.NextIdentImageKey(slug, ident.ImageS3Key, identIDString, contentType)
	})
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	app.writePresignedUploadURL(w, r, mediaUploadTarget{
		Key:           newKey,
		ContentType:   payload.ContentType,
		ResponseLabel: "ident image",
	})
}

// CommitIdentImage godoc
// @Summary		Commit ident image upload
// @Description	Stores the uploaded image key on the authenticated user's ident after validating the object exists.
// @Tags			Idents
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string						true	"Team slug"
// @Param			id		path		int							true	"Ident ID"
// @Param			payload	body		models.CommitUploadPayload	true	"Committed upload key"
// @Success		200		{object}	util.JSONResponse{data=models.CommitS3Response}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		403		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/teams/{slug}/idents/{id}/image/commit [post]
func (app *App) CommitIdentImage(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[models.CommitUploadPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}
	slug := chi.URLParam(r, "slug")
	identIDString := chi.URLParam(r, "id")
	identID64, err := strconv.ParseUint(identIDString, 10, 64)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}
	identID := uint(identID64)

	ownsIdent, err := db.UserOwnsIdentInTeam(r.Context(), app, identID, user.ID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	if !ownsIdent {
		util.ErrorJSON(w, errors.New("ident does not belong to user"), http.StatusForbidden)
		return
	}

	expectedPrefix := fmt.Sprintf("teams/%s/idents/%s/image_v", slug, identIDString)
	if !app.validateCommittedUpload(
		w,
		r,
		payload.Key,
		expectedPrefix,
		"invalid image key",
		"uploaded image not found",
	) {
		return
	}

	if err := db.UpdateIdentKey(r.Context(), app, identID, payload.Key); err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Updated ident image",
		Data: models.CommitS3Response{
			Key: payload.Key,
		},
	})
}

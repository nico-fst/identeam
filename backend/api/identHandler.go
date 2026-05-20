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
	"time"

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
// @Description	Creates an ident for the authenticated user in the team week identified by the payload time and team slug, then notifies the team.
// @Tags			Idents
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			payload	body		AddIdentPayload	true	"Ident payload"
// @Success		200		{object}	util.JSONResponse{data=models.IdentResponse}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/idents/create [post]
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

	identTime, err := time.Parse(time.RFC3339, payload.Time)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	target, err := db.GetUserWeeklyTargetByTimeUserTeam(r.Context(), app.DB, identTime, user.ID, slug)
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

	ident, err := db.CreateIdent(r.Context(), app.DB, newIdent)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	// Notify team about new ident
	_, err = db.NotifyTeamMembersAboutNewIdent(r.Context(), app.DB, &app.Provider, *ident)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Created Ident, notified team successfully",
		Data:    ident.ToDTO(),
	})
}

// DeleteIdent godoc
// @Summary		Delete ident
// @Description	Deletes the ident identified by the path ID and returns the deleted ident.
// @Tags			Idents
// @Produce		json
// @Security		BearerAuth
// @Param			id	path		int	true	"Ident ID"
// @Success		200	{object}	util.JSONResponse{data=models.IdentResponse}
// @Failure		400	{object}	util.JSONResponse
// @Failure		401	{object}	util.JSONResponse
// @Failure		500	{object}	util.JSONResponse
// @Router			/idents/{id} [delete]
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

	ident, err := db.GetIdentById(r.Context(), app.DB, uint(identID))
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	ownsIdent, err := db.UserOwnsIdentInTeam(r.Context(), app.DB, ident.ID, user.ID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	if !ownsIdent {
		util.ErrorJSON(w, errors.New("ident does not belong to user"), http.StatusForbidden)
		return
	}

	err = db.DeleteIdent(r.Context(), app.DB, *ident)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Deleted Ident successfully",
		Data:    ident.ToDTO(),
	})
}

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

	ident, err := db.GetIdentById(r.Context(), app.DB, identID)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	ownsIdent, err := db.UserOwnsIdentInTeam(r.Context(), app.DB, ident.ID, user.ID, slug)
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

	ownsIdent, err := db.UserOwnsIdentInTeam(r.Context(), app.DB, identID, user.ID, slug)
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

	if err := db.UpdateIdentKey(r.Context(), app.DB, identID, payload.Key); err != nil {
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

package api

import (
	"encoding/json"
	"errors"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
)

type AddIdentPayload struct {
	Time     string `json:"time"`
	TeamSlug string `json:"teamSlug"`
	UserText string `json:"userText"`
}

// CreateIdent godoc
// @Summary		Create ident
// @Description	Creates an ident for the authenticated user in the team week identified by the payload time and slug.
// @Tags			Idents
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			payload	body		AddIdentPayload	true	"Ident payload"
// @Success		200		{object}	util.JSONResponse{data=models.IdentResponse}
// @Failure		400		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/idents/create [post]
func (app *App) CreateIdent(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errors.New("unable to retrieve userID from context"), http.StatusInternalServerError)
		return
	}

	var payload AddIdentPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errors.New("invalid JSON"), http.StatusBadRequest)
		return
	}

	identTime, err := time.Parse(time.RFC3339, payload.Time)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	target, err := db.GetUserWeeklyTargetByTimeUserTeam(r.Context(), app.DB, identTime, user.ID, payload.TeamSlug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
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
	_, err = db.NotifyTeamMembers(r.Context(), app.DB, &app.Provider, user, payload.TeamSlug, newIdent.UserText)
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
// @Description	Deletes an ident by ID and returns the deleted ident.
// @Tags			Idents
// @Produce		json
// @Security		BearerAuth
// @Param			id	path		int	true	"Ident ID"
// @Success		200	{object}	util.JSONResponse{data=models.IdentResponse}
// @Failure		400	{object}	util.JSONResponse
// @Failure		500	{object}	util.JSONResponse
// @Router			/idents/{id} [delete]
func (app *App) DeleteIdent(w http.ResponseWriter, r *http.Request) {
	identID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	ident, err := db.GetIdentById(r.Context(), app.DB, uint(identID))
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
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

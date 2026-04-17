package api

import (
	"encoding/json"
	"errors"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
)

type CreateTargetPayload struct {
	TargetCount uint `json:"targetCount"`
}

// CreateUserTarget godoc
// @Summary		Create weekly target
// @Description	Creates a weekly target for the authenticated user in the specified team using a YYYY-MM-DD start date.
// @Tags			Targets
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			payload	body		CreateTargetPayload	true	"Weekly target payload"
// @Success		200		{object}	util.JSONResponse{data=models.UserWeeklyTargetResponse}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/targets/create [post]
func (app *App) PutUserTarget(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errors.New("unable to retrieve userID from context"), http.StatusInternalServerError)
		return
	}

	slug := chi.URLParam(r, "slug")
	dateParam := chi.URLParam(r, "dateStart")
	timeStart, err := time.Parse("2006-01-02", dateParam)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	var payload CreateTargetPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errors.New("invalid JSON"), http.StatusBadRequest)
		return
	}

	// ensure teamSlug exists
	team, err := db.GetTeamBySlug(r.Context(), app.DB, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	newTarget := models.UserWeeklyTarget{
		TimeStart:   timeStart,
		UserID:      user.ID,
		TeamID:      team.ID,
		TargetCount: payload.TargetCount,
	}

	// try creating new target
	target, err := db.CreateUserWeeklyTarget(r.Context(), app.DB, newTarget)
	if err != nil {
		// update if already exists
		if db.IsDuplicateKeyError(err) {
			existingTarget, err := db.GetUserWeeklyTargetByTimeUserTeam(r.Context(), app.DB, timeStart, user.ID, slug)
			if err != nil {
				util.ErrorJSON(w, err, http.StatusInternalServerError)
				return
			}

			target, err = db.UpdateUserWeeklyTargetCount(r.Context(), app.DB, existingTarget.ID, int(payload.TargetCount))
			if err != nil {
				util.ErrorJSON(w, err, http.StatusInternalServerError)
				return
			}
		} else {
			util.ErrorJSON(w, err, http.StatusInternalServerError)
			return
		}
	}

	// Notify about putting
	_, err = db.NotifyTeamMembersAboutTargetSet(r.Context(), app.DB, &app.Provider, target.ID)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Put UserWeeklyGoal and notified TeamMembers successfully",
		Data:    target.ToDTO(),
	})
}

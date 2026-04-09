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
)

type AddUserTargetPayload struct {
	TimeStart   string `json:"timeStart"`
	TeamSlug    string `json:"teamSlug"`
	TargetCount uint   `json:"targetCount"`
}

// CreateUserTarget godoc
// @Summary		Create weekly target
// @Description	Creates a weekly target for the authenticated user in the specified team.
// @Tags			Targets
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			payload	body		AddUserTargetPayload	true	"Weekly target payload"
// @Success		200		{object}	util.JSONResponse{data=models.UserWeeklyTargetResponse}
// @Failure		400		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/targets/create [post]
func (app *App) CreateUserTarget(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errors.New("unable to retrieve userID from context"), http.StatusInternalServerError)
		return
	}

	var payload AddUserTargetPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errors.New("invalid JSON"), http.StatusBadRequest)
		return
	}

	// ensure timeStart is date formatted
	timeStart, err := time.Parse("2006-01-02", payload.TimeStart)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	// ensure teamSlug exists
	team, err := db.GetTeamBySlug(r.Context(), app.DB, payload.TeamSlug)
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

	target, err := db.CreateUserWeeklyTarget(r.Context(), app.DB, newTarget)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Created UserWeeklyGoal successfully",
		Data:    target.ToResponse(),
	})
}

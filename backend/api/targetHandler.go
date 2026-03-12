package api

import (
	"encoding/json"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
	"time"
)

func (app *App) AddUserTarget(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	var payload models.AddUserTargetPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
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
		Data:    target,
	})
}
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

func (app *App) AddIdent(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	var payload models.AddIdentPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
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

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Created Ident successfully",
		Data:    ident,
	})
}

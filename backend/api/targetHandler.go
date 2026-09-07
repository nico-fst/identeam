package api

import (
	"errors"
	"identeam/internal/db"
	"identeam/models"
	"identeam/util"
	"net/http"
	"sort"

	"github.com/go-chi/chi/v5"
)

type PutTargetPayload struct {
	TargetDays []string `json:"targetDays"`
}

// PutTarget godoc
// @Summary		Create or replace weekly target days
// @Description	Creates or replaces up to 7 distinct planned days for the authenticated user. Future weeks are allowed; the current Europe/Berlin week can also be planned through Monday. An empty array clears planned days while retaining the weekly target. dateStart is normalized to Monday; every target day must belong to that week.
// @Tags			Targets
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			slug		path		string				true	"Team slug"
// @Param			dateStart	path		string				true	"Week start date in YYYY-MM-DD format"
// @Param			payload		body		PutTargetPayload	true	"Weekly target days payload"
// @Success		200		{object}	util.JSONResponse{data=models.TargetDTO}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/teams/{slug}/targets/{dateStart} [put]
func (app *App) PutTarget(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[PutTargetPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}

	slug := chi.URLParam(r, "slug")
	dateParam := chi.URLParam(r, "dateStart")
	timeStart, err := util.ParseDateInAppLocation(dateParam)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	dates, err := util.StringsToDates(payload.TargetDays)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	if len(dates) > 7 {
		util.ErrorJSON(w, errors.New("dates must contain <= 7 days"), http.StatusBadRequest)
		return
	}

	weekStart := util.TimeToWeekStart(timeStart) // never trust the user
	if !util.CanSetTargetWeek(weekStart, app.now()) {
		util.ErrorJSON(w, errors.New("targets can only be set for future weeks or the current week on Monday"), http.StatusBadRequest)
		return
	}
	weekEnd := weekStart.AddDate(0, 0, 7)
	seen := make(map[string]struct{})

	for _, date := range dates {
		if date.Before(weekStart) || !date.Before(weekEnd) {
			util.ErrorJSON(w, errors.New("all dates must belong to the requested week"), http.StatusBadRequest)
			return
		}

		key := date.Format("2006-01-02")
		if _, exists := seen[key]; exists {
			util.ErrorJSON(w, errors.New("date must not contain duplicates"), http.StatusBadRequest)
			return
		}
		seen[key] = struct{}{}
	}
	sort.Slice(dates, func(i, j int) bool { return dates[i].Before(dates[j]) })

	team, err := db.GetTeamBySlug(r.Context(), app, slug)
	if err != nil {
		util.ErrorJSON(w, errors.New("team not found"), http.StatusBadRequest)
		return
	}

	target, err := db.ReplaceTargetDays(
		r.Context(), app, models.Target{
			TimeStart: timeStart, UserID: user.ID, TeamID: team.ID,
		}, dates,
	)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	// Notify about putting
	_, err = db.NotifyTeamMembersAboutTargetSet(r.Context(), app, target.ID)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Put Target and notified TeamMembers successfully",
		Data:    target.ToDTO(),
	})
}

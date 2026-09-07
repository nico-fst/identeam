package api

import (
	"fmt"
	"identeam/internal/apns"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
)

type NotifyTeamDTO struct {
	Members []models.UserDTO `json:"members"`
}

// SendNotification godoc
// @Summary		Send APNs notification to one device
// @Description	Sends a push notification via APNs to the specified device token.
// @Tags			APNs
// @Produce		json
// @Param			deviceToken	path		string	true	"Device token"
// @Success		200			{object}	util.JSONResponse{data=models.Empty}
// @Failure		500			{object}	util.JSONResponse
// @Router			/notify/{deviceToken} [get]
func (app *App) SendNotification(w http.ResponseWriter, r *http.Request) {
	deviceToken := chi.URLParam(r, "deviceToken")

	notification := models.NotificationPayload{
		APS: models.APS{
			Alert: models.Alert{
				Title: "IdenTEAM",
				Body:  "A notification for your DeviceToken was triggered",
			},
		},
	}

	err := app.ApnsProvider.NotifyString(deviceToken, notification)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Success notifying user by deviceToken string",
		Data:    models.Empty{},
	})
}

// NotifyTeam godoc
// @Summary		Send APNs notification to team
// @Description	Sends a push notification to the members of the specified team and returns the notified members.
// @Tags			APNs
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string	true	"Team slug"
// @Success		200			{object}	util.JSONResponse{data=NotifyTeamDTO}
// @Failure		401			{object}	util.JSONResponse
// @Failure		500			{object}	util.JSONResponse
// @Router			/notifications/apns/team/{slug}/notify [post]
func (app *App) RemindTeam(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	team, err := db.GetTeamBySlug(r.Context(), app, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	alert := models.Alert{
		Title: fmt.Sprintf("[%v] GO GO GO", team.Name),
		Body:  user.Nickname + " reminded you",
	}

	members, err := db.NotifyTeamMembers(r.Context(), app, slug, alert)
	if err != nil {
		util.ErrorJSON(w, fmt.Errorf("unable to notify team members about new ident: %v", err), http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Success notifying team members",
		Data: NotifyTeamDTO{
			Members: models.Users(members).ToDTOs(r.Context(), app.R2Client),
		},
	})
}

// GetLocalNotificationsForWeek godoc
// @Summary		Get local notification suggestions
// @Description	Returns intelligent local notification suggestions for the authenticated user in the specified team for the week containing the required dateStart query parameter (YYYY-MM-DD, Europe/Berlin, normalized to Monday). An empty list is returned when there is not enough ident history; the client supplies its per-team default time.
// @Tags			Notifications
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string	true	"Team slug"
// @Param          dateStart query string true "Date in the requested week (YYYY-MM-DD)"
// @Failure        400 {object} util.JSONResponse
// @Success		200		{object}	util.JSONResponse{data=[]models.LocalNotificationDTO}
// @Failure		401		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/teams/{slug}/week/notifications [get]
func (app *App) GetLocalNotificationsForWeek(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}
	slug := chi.URLParam(r, "slug")
	team, err := db.GetTeamBySlug(r.Context(), app, slug)
	if err != nil {
		util.ErrorJSON(w, fmt.Errorf("ERROR team of provided slug: %w", err), http.StatusInternalServerError)
		return
	}

	dateStart, err := util.ParseDateInAppLocation(r.URL.Query().Get("dateStart"))
	if err != nil {
		util.ErrorJSON(w, fmt.Errorf("dateStart must be YYYY-MM-DD: %w", err), http.StatusBadRequest)
		return
	}
	weekStart := util.TimeToWeekStart(dateStart)

	now := util.Now()
	recentTargets, err := db.GetTargetsLast21DaysByUserTeam(
		r.Context(),
		app,
		user.ID,
		team.ID,
		now,
	)
	if err != nil {
		util.ErrorJSON(w, fmt.Errorf("ERROR querying user's targets: %w", err), http.StatusInternalServerError)
		return
	}

	dates := make([]time.Time, 0, 7)

	idents, err := db.GetIdentsOfTargets(r.Context(), app, recentTargets)
	if err != nil {
		util.ErrorJSON(w, fmt.Errorf("ERROR querying user's idents: %w", err), http.StatusInternalServerError)
		return
	}

	for offset := 0; offset < 7; offset++ {
		day := weekStart.AddDate(0, 0, offset)

		reminder, ok := apns.BuildIntelligentReminderTime(idents, day, now)
		if !ok {
			continue
		}

		dates = append(dates, reminder)
	}

	reminders := make([]models.LocalNotificationDTO, 0)
	for _, reminder := range dates {
		reminders = append(reminders, models.LocalNotificationDTO{
			Title: fmt.Sprintf("⚠️ %s needs you ⚠️", team.Name),
			Body:  "You usually ident around this time - something wrong?",
			Date:  reminder,
		})
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Gathered notification times for requested week",
		Data:    reminders,
	})
}

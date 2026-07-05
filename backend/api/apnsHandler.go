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
func (app *App) NotifyTeam(w http.ResponseWriter, r *http.Request) {
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
			Members: models.Users(members).ToDTOs(),
		},
	})
}

// GetLocalNotificationsForWeek godoc
// @Summary		Get local notification suggestions
// @Description	Returns suggested local notification times for the authenticated user in the specified team for the upcoming week.
// @Tags			Notifications
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string	true	"Team slug"
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

	// TODO erst wenn Wochentage spezifiziert werden
	// upcomingTargets, err := db.GetTargetsByUserTeam(
	// 	r.Context(),
	// 	app,
	// 	user.ID,
	// 	team.ID,
	// 	util.NextMon(time.Now().AddDate(0, 0, -7)),
	// )
	// if err != nil {
	// 	util.ErrorJSON(w, fmt.Errorf("ERROR querying user's targets: %w", err), http.StatusInternalServerError)
	// 	return
	// }

	sameLast3Targets, err := db.GetTargetsLast21DaysByUserTeam(
		r.Context(),
		app,
		user.ID,
		team.ID,
		time.Now(),
	)

	dates := make([]time.Time, 0, 7)

	idents, err := db.GetIdentsOfTargets(r.Context(), app, sameLast3Targets)
	if err != nil {
		util.ErrorJSON(w, fmt.Errorf("ERROR querying user's idents: %w", err), http.StatusInternalServerError)
		return
	}

	for _, day := range util.NextMonToSun(time.Now()) {

		reminder, ok := apns.BuildIntelligentReminderTime(idents, day)
		if !ok {
			util.ErrorJSON(w, fmt.Errorf("ERROR calculating dates: %w", err), http.StatusInternalServerError)
			return
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
		Message: "Gathered notification times for upcoming week",
		Data:    reminders,
	})
}

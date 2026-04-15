package api

import (
	"errors"
	"fmt"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"

	"github.com/go-chi/chi/v5"
)

type NotifyTeamResponse struct {
	Members []models.UserResponse `json:"members"`
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

	err := app.Provider.NotifyString(deviceToken, notification)
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
// @Success		200			{object}	util.JSONResponse{data=NotifyTeamResponse}
// @Failure		401			{object}	util.JSONResponse
// @Failure		500			{object}	util.JSONResponse
// @Router			/notify/team/{slug} [post]
func (app *App) NotifyTeam(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errors.New("unable to retrieve userID from context"), http.StatusInternalServerError)
		return
	}

	alert := models.Alert{
		Title: "Notified Team " + slug,
		Body: "Triggered by " + user.FullName,
	}

	members, err := db.NotifyTeamMembers(r.Context(), app.DB, &app.Provider, user, slug, alert)
	if err != nil {
		util.ErrorJSON(w, fmt.Errorf("unable to notify team members about new ident: %v", err), http.StatusInternalServerError)
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Success notifying team members",
		Data: NotifyTeamResponse{
			Members: models.Users(members).ToDTOs(),
		},
	})
}

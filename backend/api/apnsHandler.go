package api

import (
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"

	"github.com/go-chi/chi/v5"
)

// @Summary		Send APNs Notification
// @Description	Sends a push notification via APNs to the specified device token.
// @Tags			APNs
// @Accept			json
// @Produce		json
// @Param			deviceToken	path		string				true	"Device Token to send the notification to"
// @Success		200			{object}	util.JSONResponse	"Returns the result of the APNs send call"
// @Failure		400			{object}	util.JSONResponse	"Invalid device token or request"
// @Failure		500			{object}	util.JSONResponse	"Server error sending the notification"
// @Router			/trigger/{deviceToken} [get]
func (app *App) SendNotification(w http.ResponseWriter, r *http.Request) {
	deviceToken := chi.URLParam(r, "deviceToken")

	err := app.Provider.NotifyString(deviceToken, models.NotificationTemplates[models.NewIdent])
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
	}
	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Success notifying user by deviceToken string",
		Data:    models.Empty{},
	})
}

func (app *App) NotifyTeam(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	memberPointers, err := db.GetTeamMembers(r.Context(), app.DB, user.UserID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
	}
	members := db.DerefUsers(memberPointers)

	err = app.Provider.NotifyUsers(members, models.NotificationTemplates[models.NewIdent])
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Success notifying team members",
		Data:    members,
	})
}

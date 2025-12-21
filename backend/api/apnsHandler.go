package api

import (
	"encoding/json"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"

	"github.com/go-chi/chi/v5"
)

// // @Summary		Send APNs Notification
// // @Description	Sends a push notification via APNs to the specified device token.
// // @Tags			APNs
// // @Accept			json
// // @Produce		json
// // @Param			deviceToken	path		string				true	"Device Token to send the notification to"
// // @Success		200			{object}	util.JSONResponse	"Returns the result of the APNs send call"
// // @Failure		400			{object}	util.JSONResponse	"Invalid device token or request"
// // @Failure		500			{object}	util.JSONResponse	"Server error sending the notification"
// // @Router			/trigger/{deviceToken} [get]
// func (app *App) SendNotification(w http.ResponseWriter, r *http.Request) {
// 	deviceToken := chi.URLParam(r, "deviceToken")

// 	res:= app.Provider.NotifyUser(deviceToken, "OMG das ist go nicht paris!")

// 	payload := util.JSONResponse{
// 		Error:   false,
// 		Message: "APNs call result",
// 		Data:    res.Sent(),
// 	}

// 	err = util.WriteJSON(w, http.StatusOK, payload)
// 	if err != nil {
// 		log.Println(err)
// 	}
// }

func (app *App) NotifyTeam(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	var payload models.UpdateUserPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	memberPointers, err := db.GetTeamMembers(r.Context(), app.DB, user.UserID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
	}
	members := db.DerefUsers(memberPointers)

	app.Provider.NotifyUsers(members, models.NotificationTemplates[models.NewIdent])
}

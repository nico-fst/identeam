package api

import (
	"identeam/util"
	"log"
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

	res, err := app.Provider.SendNotification(deviceToken, "OMG das ist go nicht paris!")
	if err != nil {
		log.Fatal(err)
	}

	payload := util.JSONResponse{
		Error:   false,
		Message: "APNs call result",
		Data:    res.Sent(),
	}

	err = util.WriteJSON(w, http.StatusOK, payload)
	if err != nil {
		log.Println(err)
	}
}

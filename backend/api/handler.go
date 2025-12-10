package api

import (
	"identeam/util"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
)

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

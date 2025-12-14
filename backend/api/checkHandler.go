package api

import (
	"identeam/middleware"
	"net/http"
)

func (app *App) CheckSession(w http.ResponseWriter, r *http.Request) {
	_, ok := middleware.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

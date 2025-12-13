package api

import (
	"identeam/middleware"
	"net/http"
)

// Checks if Client's Session Token is (still) valid
func (app *App) CheckSession(w http.ResponseWriter, r *http.Request) {
	_, ok := middleware.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, "unable to retrieve user ID from context", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

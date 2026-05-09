package api

import (
	"context"
	"encoding/json"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"io"
	"net/http"
)

func userAndPayload[T any](ctx context.Context, body io.Reader, w http.ResponseWriter) (models.User, T, bool) {
	var payload T

	user, ok := middleware.GetUserFromContext(ctx)
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return models.User{}, payload, false
	}

	if err := json.NewDecoder(body).Decode(&payload); err != nil {
		util.ErrorJSON(w, errInvalidJSON, http.StatusBadRequest)
		return models.User{}, payload, false
	}

	return user, payload, true
}

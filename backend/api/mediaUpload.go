package api

import (
	"errors"
	"fmt"
	"identeam/internal/media"
	"identeam/models"
	"identeam/util"
	"net/http"
	"strings"
	"time"
)

type mediaUploadTarget struct {
	Key           string
	ContentType   string
	ResponseLabel string
}

func (app *App) writePresignedUploadURL(w http.ResponseWriter, r *http.Request, target mediaUploadTarget) bool {
	expiresAt := time.Now().Add(10 * time.Minute)

	uploadURL, err := app.R2Client.PresignPutObject(r.Context(), target.Key, target.ContentType, expiresAt)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return false
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: fmt.Sprintf("Created %s PUT URL", target.ResponseLabel),
		Data: models.PresignedResponse{
			Key:          target.Key,
			PresignedURL: uploadURL,
			ExpiresAt:    expiresAt,
		},
	})
	return true
}

func (app *App) validateCommittedUpload(w http.ResponseWriter, r *http.Request, key string, expectedPrefix string, invalidKeyMessage string, missingObjectMessage string) bool {
	if !strings.HasPrefix(key, expectedPrefix) {
		util.ErrorJSON(w, errors.New(invalidKeyMessage), http.StatusBadRequest)
		return false
	}

	if err := app.R2Client.CheckExistence(r.Context(), key); err != nil {
		util.ErrorJSON(w, errors.New(missingObjectMessage), http.StatusBadRequest)
		return false
	}

	return true
}

func nextValidatedImageKey(payload models.PresignedRequestPayload, keyFn func(string) (string, error)) (string, error) {
	if err := media.ValidateImage(payload.ContentType, payload.SizeBytes); err != nil {
		return "", err
	}

	return keyFn(payload.ContentType)
}

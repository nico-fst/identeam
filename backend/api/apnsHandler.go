package api

import (
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

	err := app.Provider.NotifyString(deviceToken, models.NotificationTemplates[models.NewIdent])
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
// @Description	Sends a push notification to all members of a team the authenticated user belongs to.
// @Tags			APNs
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string	true	"Team slug"
// @Success		200			{object}	util.JSONResponse{data=NotifyTeamResponse}
// @Failure		400			{object}	util.JSONResponse
// @Failure		500			{object}	util.JSONResponse
// @Router			/notify/team/{slug} [post]
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
		return
	}
	members := db.DerefUsers(memberPointers)

	err = app.Provider.NotifyUsers(members, models.NotificationTemplates[models.NewIdent])
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	membersResponse := make([]models.UserResponse, 0, len(members))
	for _, member := range members {
		membersResponse = append(membersResponse, models.UserResponse{
			UserID:   member.UserID,
			Email:    member.Email,
			FullName: member.FullName,
			Username: member.Username,
		})
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Success notifying team members",
		Data: NotifyTeamResponse{
			Members: membersResponse,
		},
	})
}

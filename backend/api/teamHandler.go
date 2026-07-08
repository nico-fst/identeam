package api

import (
	"errors"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
)

type AddTeamPayload struct {
	Name                 string `json:"name"`
	Details              string `json:"details"`
	NotificationTemplate string `json:"notificationTemplate"`
}

// AddTeam godoc
//
//	@Summary		Create a new team
//	@Description	Creates a new team and immediately adds the authenticated user to it.
//	@Tags			Teams
//	@Accept			json
//	@Produce		json
//	@Security		BearerAuth
//	@Param			payload	body		AddTeamPayload	true	"Team data"
//	@Success		200		{object}	util.JSONResponse{data=models.TeamDTO}
//	@Failure		400		{object}	util.JSONResponse
//	@Failure		401		{object}	util.JSONResponse
//	@Failure		500		{object}	util.JSONResponse
//	@Router			/teams/create [post]
func (app *App) CreateTeam(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[AddTeamPayload](r.Context(), r.Body, w)
	if !ok {
		return
	}

	team := models.Team{
		Name:                 payload.Name,
		Slug:                 util.MakeValidSlug(payload.Name),
		Details:              payload.Details,
		NotificationTemplate: &payload.NotificationTemplate,
	}

	newTeam, err := db.CreateTeam(r.Context(), app, team)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	_, err = db.AddUserToTeam(r.Context(), app, user.UserID, newTeam.Slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Created, joined team successfully",
		Data:    newTeam.ToDTO(),
	})
}

type AddUserToTeamDTO struct {
	User models.UserDTO `json:"user"`
	Team models.TeamDTO `json:"team"`
}

// JoinTeam godoc
//
//	@Summary		Join a team
//	@Description	Adds the authenticated user to the team identified by the slug and returns both user and team data.
//	@Tags			Teams
//	@Produce		json
//	@Security		BearerAuth
//	@Param			slug	path		string	true	"Team slug"
//	@Success		200		{object}	util.JSONResponse{data=AddUserToTeamDTO}
//	@Failure		400		{object}	util.JSONResponse
//	@Failure		401		{object}	util.JSONResponse
//	@Failure		500		{object}	util.JSONResponse
//	@Router			/teams/{slug}/join [post]
func (app *App) JoinTeam(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	slug := strings.ToLower(chi.URLParam(r, "slug"))

	team, err := db.AddUserToTeam(r.Context(), app, user.UserID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Added user to team successfully or already joined",
		Data: AddUserToTeamDTO{
			User: user.ToDTO(r.Context(), app.R2Client),
			Team: team.ToDTO(),
		},
	})
}

// LeaveTeam godoc
//
//	@Summary		Leave a team
//	@Description	Removes the authenticated user from the team identified by the slug and returns both user and team data.
//	@Tags			Teams
//	@Produce		json
//	@Security		BearerAuth
//	@Param			slug	path		string	true	"Team slug"
//	@Success		200		{object}	util.JSONResponse{data=AddUserToTeamDTO}
//	@Failure		400		{object}	util.JSONResponse
//	@Failure		401		{object}	util.JSONResponse
//	@Failure		500		{object}	util.JSONResponse
//	@Router			/teams/{slug}/leave [post]
func (app *App) LeaveTeam(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	team, err := db.RemoveUserFromTeam(r.Context(), app, user.UserID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Removed user from team successfully or was no member",
		Data: AddUserToTeamDTO{
			User: user.ToDTO(r.Context(), app.R2Client),
			Team: team.ToDTO(),
		},
	})
}

type GetMyTeamsResponse struct {
	Teams []models.TeamDTO `json:"teams"`
}

// GetMyTeams godoc
//
//	@Summary		Get my teams
//	@Description	Returns all teams currently associated with the authenticated user.
//	@Tags			Teams
//	@Produce		json
//	@Security		BearerAuth
//	@Success		200	{object}	util.JSONResponse{data=GetMyTeamsResponse}
//	@Failure		401	{object}	util.JSONResponse
//	@Failure		500	{object}	util.JSONResponse
//	@Router			/teams/me [get]
func (app *App) GetMyTeams(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Retrieved teams from user successfully",
		Data: GetMyTeamsResponse{
			Teams: models.Teams(user.Teams).ToDTOs(),
		},
	})
}

// GetTeamWeek godoc
//
//	@Summary		Get team week overview
//	@Description	Returns the team week overview, including weekly targets and idents for the provided YYYY-MM-DD week start date.
//	@Tags			Teams
//	@Produce		json
//	@Security		BearerAuth
//	@Param			slug	path		string	true	"Team slug"
//	@Param			dateStart	path		string	true	"Week start date in YYYY-MM-DD format"
//	@Success		200		{object}	util.JSONResponse{data=models.TeamWeekResponse}
//	@Failure		400		{object}	util.JSONResponse
//	@Failure		401		{object}	util.JSONResponse
//	@Router			/teams/{slug}/week/{dateStart} [get]
func (app *App) GetTeamWeek(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	dateParam := chi.URLParam(r, "dateStart")
	date, err := util.ParseDateInAppLocation(dateParam)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	if slug == "" || dateParam == "" {
		util.ErrorJSON(w, errors.New("{slug} and {dateStart} must be specified"), http.StatusBadRequest)
		return
	}

	teamWeek, err := db.GetTeamWeek(r.Context(), app, slug, date)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, http.StatusOK, util.JSONResponse{
		Error:   false,
		Message: "Retrieved team week successfully",
		Data:    teamWeek,
	})
}

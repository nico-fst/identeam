package api

import (
	"encoding/json"
	"identeam/internal/db"
	"identeam/middleware"
	"identeam/models"
	"identeam/util"
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
)

// AddTeam godoc
//
//	@Summary		Create a new team
//	@Description	Creates a new team owned by the authenticated user
//	@Tags			Teams
//	@Accept			json
//	@Produce		json
//	@Security		BearerAuth
//	@Param			payload	body		models.AddTeamPayload	true	"Team data"
//	@Success		200		{object}	util.JSONResponse{data=models.TeamResponse}
//	@Failure		400		{object}	util.JSONResponse
//	@Failure		401		{object}	util.JSONResponse
//	@Router			/teams/add [post]
func (app *App) AddTeam(w http.ResponseWriter, r *http.Request) {
	var payload models.AddTeamPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}

	newTeam, err := db.CreateTeam(r.Context(), app.DB, payload.Team)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Created team successfully",
		Data: models.TeamResponse{
			Name:        newTeam.Name,
			Slug:        newTeam.Slug,
			Description: newTeam.Description,
		},
	})
}

type AddUserToTeamResponse struct {
	User models.UserResponse `json:"user"`
	Team models.TeamResponse `json:"team"`
}

// JoinTeam godoc
//
//	@Summary		Join a team
//	@Description	Adds the authenticated user to a team identified by its slug
//	@Tags			Teams
//	@Produce		json
//	@Security		BearerAuth
//	@Param			slug	path		string	true	"Team slug"
//	@Success		200		{object}	util.JSONResponse{data=AddUserToTeamResponse}
//	@Failure		400		{object}	util.JSONResponse
//	@Failure		401		{object}	util.JSONResponse
//	@Failure		404		{object}	util.JSONResponse
//	@Router			/teams/join/{slug} [post]
func (app *App) JoinTeam(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}
	log.Println(user)

	slug := chi.URLParam(r, "slug")

	team, err := db.AddUserToTeam(r.Context(), app.DB, user.UserID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Added user to team successfully or already joined",
		Data: AddUserToTeamResponse{
			User: models.UserResponse{
				UserID:   user.UserID,
				Email:    user.Email,
				FullName: user.FullName,
				Username: user.Username,
			},
			Team: models.TeamResponse{
				Name:        team.Name,
				Slug:        team.Slug,
				Description: team.Description,
			},
		},
	})
}

// LeaveTeam godoc
//
//	@Summary		Leave a team
//	@Description	Removes the authenticated user from a team identified by its slug
//	@Tags			Teams
//	@Produce		json
//	@Security		BearerAuth
//	@Param			slug	path		string	true	"Team slug"
//	@Success		200		{object}	util.JSONResponse{data=AddUserToTeamResponse}
//	@Failure		400		{object}	util.JSONResponse
//	@Failure		401		{object}	util.JSONResponse
//	@Failure		404		{object}	util.JSONResponse
//	@Router			/teams/leave/{slug} [post]
func (app *App) LeaveTeam(w http.ResponseWriter, r *http.Request) {
	slug := chi.URLParam(r, "slug")
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		http.Error(w, "Unable to retrieve userID from context", http.StatusInternalServerError)
		return
	}

	team, err := db.RemoveUserFromTeam(r.Context(), app.DB, user.UserID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Removed user from team successfully or was no member",
		Data: AddUserToTeamResponse{
			User: models.UserResponse{
				UserID:   user.UserID,
				Email:    user.Email,
				FullName: user.FullName,
				Username: user.Username,
			},
			Team: models.TeamResponse{
				Name:        team.Name,
				Slug:        team.Slug,
				Description: team.Description,
			},
		},
	})
}

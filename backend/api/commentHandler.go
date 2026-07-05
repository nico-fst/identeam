package api

import (
	"errors"
	"identeam/internal/db"
	"identeam/util"
	"net/http"

	"github.com/go-chi/chi/v5"
)

type CommentIdentpayload struct {
	Text string `json:"text"`
}

// CommentIdent godoc
// @Summary		Comment on ident
// @Description	Creates a comment on an ident in the specified team for the authenticated user, then notifies the team.
// @Tags			Comments
// @Accept			json
// @Produce		json
// @Security		BearerAuth
// @Param			slug	path		string				true	"Team slug"
// @Param			id		path		int					true	"Ident ID"
// @Param			payload	body		CommentIdentpayload	true	"Comment payload"
// @Success		200		{object}	util.JSONResponse{data=models.CommentDTO}
// @Failure		400		{object}	util.JSONResponse
// @Failure		401		{object}	util.JSONResponse
// @Failure		403		{object}	util.JSONResponse
// @Failure		500		{object}	util.JSONResponse
// @Router			/teams/{slug}/idents/{id}/comment [post]
func (app *App) CommentIdent(w http.ResponseWriter, r *http.Request) {
	user, payload, ok := userAndPayload[CommentIdentpayload](r.Context(), r.Body, w)
	if !ok {
		return
	}
	slug := chi.URLParam(r, "slug")
	identID, err := util.StringToUint64(chi.URLParam(r, "id"))
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	// Guard: allowed to comment
	isInTeam, err := db.UserIsInIdentsTeam(r.Context(), app, identID, user.ID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	if !isInTeam {
		util.ErrorJSON(w, errors.New("user is not in ident's team"), http.StatusForbidden)
		return
	}

	// comment
	comment, err := db.CreateComment(r.Context(), app, user.ID, identID, payload.Text)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	// notify team
	_, err = db.NotifyTeamMembersAboutNewComment(r.Context(), app, comment, user.ID)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Created Comment, notified team successfully",
		Data:    comment.ToDTO(),
	})
}

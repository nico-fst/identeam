package api

import (
	"errors"
	"identeam/internal/db"
	"identeam/middleware"
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
		Data:    comment.ToDTO(r.Context(), app.R2Client),
	})
}

// UncommentIdent godoc
// @Summary		Delete comment on ident
// @Description	Deletes the authenticated user's comment from the specified ident in the specified team.
// @Tags			Comments
// @Produce		json
// @Security		BearerAuth
// @Param			slug		path		string	true	"Team slug"
// @Param			id			path		int		true	"Ident ID"
// @Param			commentID	path		int		true	"Comment ID"
// @Success		200			{object}	util.JSONResponse{data=models.CommentDTO}
// @Failure		400			{object}	util.JSONResponse
// @Failure		401			{object}	util.JSONResponse
// @Failure		403			{object}	util.JSONResponse
// @Failure		500			{object}	util.JSONResponse
// @Router			/teams/{slug}/idents/{id}/uncomment/{commentID} [delete]
func (app *App) UncommentIdent(w http.ResponseWriter, r *http.Request) {
	user, ok := middleware.GetUserFromContext(r.Context())
	if !ok {
		util.ErrorJSON(w, errUnableToRetrieveUserIDFromContext, http.StatusInternalServerError)
		return
	}

	slug := chi.URLParam(r, "slug")
	identID, err := util.StringToUint64(chi.URLParam(r, "id"))
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}
	commentID, err := util.StringToUint64(chi.URLParam(r, "commentID"))
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	comment, err := db.GetCommentById(r.Context(), app, commentID)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	ownsComment, err := db.UserOwnsCommentOnIdentInTeam(r.Context(), app, commentID, identID, user.ID, slug)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusInternalServerError)
		return
	}
	if !ownsComment {
		util.ErrorJSON(w, errors.New("comment does not belong to user on ident in team"), http.StatusForbidden)
		return
	}

	err = db.DeleteComment(r.Context(), app, *comment)
	if err != nil {
		util.ErrorJSON(w, err, http.StatusBadRequest)
		return
	}

	util.WriteJSON(w, 200, util.JSONResponse{
		Error:   false,
		Message: "Deleted Comment successfully",
		Data:    comment.ToDTO(r.Context(), app.R2Client),
	})
}

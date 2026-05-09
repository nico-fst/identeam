package api

import "errors"

var (
	// Middleware, parsing
	errUnableToRetrieveUserIDFromContext = errors.New("unable to retrieve userID from context")
	errInvalidJSON                       = errors.New("invalid JSON")
)

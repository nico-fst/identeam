package middleware

import (
	"context"
	"errors"
	"identeam/internal/auth"
	"identeam/internal/db"
	"identeam/models"
	"identeam/util"
	"log"
	"net/http"
	"strings"

	"gorm.io/gorm"
)

type ctxKey string

const userIDKey ctxKey = "userID"
const userObjectKey ctxKey = "userObject"

func JWTAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			util.ErrorJSON(w, errors.New("missing authorization header"), http.StatusUnauthorized)
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) == 1 && parts[0] == "Bearer" {
			util.ErrorJSON(w, errors.New("bearer token empty"), http.StatusUnauthorized)
			return
		}
		if len(parts) != 2 || parts[0] != "Bearer" {
			util.ErrorJSON(w, errors.New("invalid authorization header format"), http.StatusUnauthorized)
			return
		}

		tokenString := parts[1]
		claims, err := auth.VerifySessionToken(tokenString)
		if err != nil {
			util.ErrorJSON(w, errors.New("invalid or expired token"), http.StatusUnauthorized)
			return
		}

		log.Printf("[JWT Middleware] User authenticated using valid JWT - userID: %s\n", claims.UserID)
		// put user into context as userObjectKey == "userID"
		ctx := context.WithValue(r.Context(), userIDKey, claims.UserID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func GetUserIDFromContext(ctx context.Context) (string, bool) {
	id, ok := ctx.Value(userIDKey).(string)
	return id, ok
}

func InjectUser(pDB *gorm.DB) func(http.Handler) http.Handler { // returns func(...) which returns http.Handler
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID, ok := GetUserIDFromContext(r.Context())
			if !ok {
				util.ErrorJSON(w, errors.New("user id missing in context for middleware"), http.StatusUnauthorized)
				return
			}

			user, err := db.GetUserById(r.Context(), pDB, userID)
			if err != nil {
				// User has valid JWT but doesn't exist in DB -> return 401
				log.Printf("[InjectUser Middleware] User with valid JWT not found in DB - userID: %s", userID)
				util.ErrorJSON(w, errors.New("user not found in database"), http.StatusUnauthorized)
				return
			}

			log.Printf("[InjectUser Middleware] Injected User with id %v into context", userID)
			ctx := context.WithValue(r.Context(), userObjectKey, *user)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func GetUserFromContext(ctx context.Context) (models.User, bool) {
	user, ok := ctx.Value(userObjectKey).(models.User)
	return user, ok
}

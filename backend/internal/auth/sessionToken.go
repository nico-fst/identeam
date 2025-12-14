package auth

import (
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var sessionSecret = []byte(os.Getenv("SESSION_TOKEN_SECRET"))

type MyClaims struct {
	UserID string `json:"userID"`
	Email  string `json:"email,omitempty"`
	jwt.RegisteredClaims
}

func CreateSessionToken(userID, email string) (string, error) {
	claims := MyClaims{
		UserID: userID,
		Email:  email,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour * 24 * 30)), // expiry 30 days
			Issuer:    "identeam",
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(sessionSecret)
}

func VerifySessionToken(tokenString string) (*MyClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &MyClaims{}, func(t *jwt.Token) (interface{}, error) {
		return sessionSecret, nil
	})
	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*MyClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("invalid token")
}

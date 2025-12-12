package auth

import (
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/sessions"
	"github.com/markbates/goth"
	"github.com/markbates/goth/gothic"
	"github.com/markbates/goth/providers/apple"
)

const (
	Key    = "changeThat"
	MaxAge = 86400 * 30 // 30 days
	IsProd = false
)

// Setup goth for SIWA with session store
func NewAuth() {
	clientID := os.Getenv("SIWA_CLIENT_ID")
	secret := os.Getenv("SIWA_SECRET")
	redirectURL := os.Getenv("SIWA_CALLBACK_URL")

	// Setup session store (OAuth is stateless, gothic.Store allows storing temp data in Cookie)
	store := sessions.NewCookieStore(([]byte(Key)))
	store.MaxAge(MaxAge)
	store.Options.Path = "/"
	store.Options.HttpOnly = true
	store.Options.Secure = IsProd
	store.Options.Domain = "unconvolute-effectively-leeanna.ngrok-free.dev"

	gothic.Store = store

	// Goth setup for SIWA
	goth.UseProviders(
		apple.New(clientID, secret, redirectURL, nil, apple.ScopeName, apple.ScopeEmail),
	)
}

func GenerateAppleClientSecret(p8Path, teamID, clientID, keyID string) (string, error) {
	keyBytes, err := os.ReadFile(p8Path)
	if err != nil {
		return "", err
	}

	privKey, err := jwt.ParseECPrivateKeyFromPEM(keyBytes)
	if err != nil {
		return "", err
	}

	now := time.Now()

	claims := jwt.MapClaims{
		"iss": teamID,
		"iat": now.Unix(),
		"exp": now.Add(180 * 24 * time.Hour).Unix(), // max 6 Monate
		"aud": "https://appleid.apple.com",
		"sub": clientID,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodES256, claims)
	token.Header["kid"] = keyID

	return token.SignedString(privKey)
}

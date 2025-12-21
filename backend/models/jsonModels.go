package models

type Empty struct{}

// API RESPONSES

// since different notations and []DeviceTokens would complicate decoding in Swift
type UserResponse struct {
	UserID   string `json:"userID"`
	Email    string `json:"email"`
	FullName string `json:"fullName"`
	Username string `json:"username"`
}

type TeamResponse struct {
	Name        string `json:"name"`
	Slug        string `json:"slug"`
	Description string `json:"description"`
}

// PAYLOADS (grouped here for swaggo)

type SignInPayload struct {
	IdentityToken     string `json:"identityToken"`
	AuthorizationCode string `json:"authorizationCode"`
	UserID            string `json:"userID"`
	FullName          string `json:"fullName"`
}

type UpdateDeviceTokenPayload struct {
	NewToken string `json:"newToken"`
	Platform string `json:"platform"`
}

type UpdateUserPayload struct {
	User User `json:"user"`
}

type AddTeamPayload struct {
	Team Team `json:"team"`
}

type NotifyGroupPayload struct {
	Content string `json:"content"`
}

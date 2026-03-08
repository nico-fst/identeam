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
	Name    string `json:"name"`
	Slug    string `json:"slug"`
	Details string `json:"details"`
}

// PAYLOADS (grouped here for swaggo)

type AuthApplePayload struct {
	IdentityToken     string `json:"identityToken"`
	AuthorizationCode string `json:"authorizationCode"`
	UserID            string `json:"userID"`
	FullName          string `json:"fullName"`
}

type LoginPasswordPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type SignupPasswordPayload struct {
	Email    string `json:"email"`
	Password string `json:"password"`
	FullName string `json:"fullName"`
	Username string `json:"username"`
}

type UpdateDeviceTokenPayload struct {
	NewToken string `json:"newToken"`
	Platform string `json:"platform"`
}

type UpdateUserPayload struct {
	User UpdateUserData `json:"user"`
}

type UpdateUserData struct {
	FullName string `json:"fullName"`
	Username string `json:"username"`
}

type AddTeamPayload struct {
	Name    string `json:"name"`
	Details string `json:"details"`
}

type NotifyGroupPayload struct {
	Content string `json:"content"`
}

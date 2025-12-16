package models

type Empty struct{}

// since different notations and []DeviceTokens would complicate decoding in Swift
type UserResponse struct {
	UserID   string `json:"userID"`
	Email    string `json:"email"`
	FullName string `json:"fullName"`
	Username string `json:"username"`
}

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

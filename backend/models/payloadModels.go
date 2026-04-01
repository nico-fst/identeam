package models

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

type AddUserTargetPayload struct {
	TimeStart   string `json:"timeStart"`
	TeamSlug    string `json:"teamSlug"`
	TargetCount uint   `json:"targetCount"`
}

type AddIdentPayload struct {
	Time     string `json:"time"`
	TeamSlug string `json:"teamSlug"`
	UserText string `json:"userText"`
}

type DeleteIdentPayload struct {
	IdentID uint `json:"identID"`
}
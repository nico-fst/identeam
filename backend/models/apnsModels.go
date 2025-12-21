package models

type Alert struct {
	Title    string `json:"title"`
	Subtitle string `json:"subtitle"`
	Body     string `json:"body"`
}

type APS struct {
	Alert    Alert  `json:"alert"`
	Category string `json:"category"` // for interactive notifications: action buttons
}

type NotificationPayload struct {
	APS APS `json:"aps"`
}

type NotificationType string

const (
	NewIdent NotificationType = "NEW_IDENT"
)

var NotificationTemplates = map[NotificationType]NotificationPayload{
	NewIdent: {
		APS: APS{
			Alert: Alert{
				Title: "Neuer Ident",
				Body:  "OMG Greta ist mies am Gym hitten 🔥",
			},
		},
	},
}

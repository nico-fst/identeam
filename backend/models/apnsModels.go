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

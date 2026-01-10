package apns

import (
	"identeam/models"
	"log"

	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/token"
)

type Provider struct {
	// APNs config
	KeyId   string
	TeamId  string
	KeyFile string
	Topic   string
	// Pointer to APNs client (for sending notifications)
	Client *apns2.Client
}

func (provider *Provider) SetupProvider() *Provider {
	authKey, err := token.AuthKeyFromFile(provider.KeyFile) // reads .p8 file
	if err != nil {
		log.Fatal(err)
	}

	newToken := &token.Token{
		AuthKey: authKey,
		KeyID:   provider.KeyId,
		TeamID:  provider.TeamId,
	}

	// generates new dev APNs-client using token
	provider.Client = apns2.NewTokenClient(newToken).Development()
	log.Println("APNs client created")
	return provider
}

func (provider *Provider) NotifyString(deviceToken string, notification models.NotificationPayload) error {
	notificationPayload := &apns2.Notification{
		DeviceToken: deviceToken,
		Topic:       provider.Topic,
		Payload:     notification,
	}

	_, err := provider.Client.Push(notificationPayload)
	if err != nil {
		log.Fatal(err)
		return err
	}

	return nil
}

// pushed Notification to all of user's deviceTokens
func (provider *Provider) NotifyDeviceTokens(deviceTokens []models.DeviceToken, notification models.NotificationPayload) error {
	for _, deviceToken := range deviceTokens {
		notification := &apns2.Notification{
			DeviceToken: deviceToken.Token,
			Topic:       provider.Topic,
			Payload:     notification,
		}

		_, err := provider.Client.Push(notification)
		if err != nil {
			log.Fatal(err)
			return err
		}
	}

	return nil
}

func (provider *Provider) NotifyUsers(users []models.User, notification models.NotificationPayload) error {
	for _, user := range users {
		err := provider.NotifyDeviceTokens(user.DeviceTokens, notification)
		if err != nil {
			log.Fatal(err)
			return err
		}
	}

	return nil
}

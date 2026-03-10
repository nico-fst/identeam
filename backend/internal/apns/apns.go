package apns

import (
	"fmt"
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
	IsProd bool // tokens are only valid in "production" or "development" env
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
	if provider.IsProd {
		provider.Client = apns2.NewTokenClient(newToken).Production()
	} else {
		provider.Client = apns2.NewTokenClient(newToken).Development()
	}
	log.Printf("APNs client created (IsProd = %v)", provider.IsProd)
	return provider
}

func (provider *Provider) NotifyString(deviceToken string, notification models.NotificationPayload) error {
	notificationPayload := &apns2.Notification{
		DeviceToken: deviceToken,
		Topic:       provider.Topic,
		Payload:     notification,
	}

	return provider.push(notificationPayload)
}

// pushed Notification to all of user's deviceTokens
func (provider *Provider) NotifyDeviceTokens(deviceTokens []models.DeviceToken, notification models.NotificationPayload) error {
	for _, deviceToken := range deviceTokens {
		notificationPayload := &apns2.Notification{
			DeviceToken: deviceToken.Token,
			Topic:       provider.Topic,
			Payload:     notification,
		}

		err := provider.push(notificationPayload)
		if err != nil {
			return err
		}
	}

	return nil
}

func (provider *Provider) NotifyUsers(users []models.User, notification models.NotificationPayload) error {
	for _, user := range users {
		err := provider.NotifyDeviceTokens(user.DeviceTokens, notification)
		if err != nil {
			return err
		}
	}

	return nil
}

func (provider *Provider) push(notification *apns2.Notification) error {
	res, err := provider.Client.Push(notification)
	if err != nil {
		log.Printf("APNs transport error for token %s: %v", notification.DeviceToken, err)
		return err
	}

	if !res.Sent() {
		err = fmt.Errorf(
			"apns rejected notification for token %s: status=%d reason=%s apns_id=%s",
			notification.DeviceToken,
			res.StatusCode,
			res.Reason,
			res.ApnsID,
		)
		log.Println(err)
		return err
	}

	log.Printf("APNs accepted notification for token %s (apns_id=%s)", notification.DeviceToken, res.ApnsID)
	return nil
}

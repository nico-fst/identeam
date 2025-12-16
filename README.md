# IdenTEAM

Start your habit challenge now - elevate your **iden**tity as a TEAM!

# Dev Setup

## Setup

- Create `/backend/.env` (like `.example.env`) with values from Apple Developer
  - Use Ngrok if a HTTPS redirect URL for WebAuth is necessary (enforced by Apple)
- Insert `/backend/apns_key.p8` (created as Key for APNs on Apple Developer)
- Insert `/backend/siwa_key.p8` (created as Key for SIWA on Apple Developer)

> Manual: After installing packages with `go mod tidy`, the server can be started via `go run main.go`.

> VSCode: Debug config in `.vscode/launch.json` (uses dlv) allows debugging in VSCode.

# Understanding

## Sign in with Apple Auth Flow (SIWA, Native on iOS)

Drastically simplified process:

1. **[Client]** User presses SIWA Button; sends form
2. **[Client <-> Apple server]** Apple provides `ASAuthorizationAppleIDCredential` (containing `userID`, `email`, `fullname`, `identityToken`, `authorizationCode`)
3. **[Client -> Backend]** Sends `identityToken` (JWT), `authorizationCode`, `userID`, ..., e.g.:

```json
POST /auth/apple/native/callback
{
  "identityToken": "...",
  "authorizationCode": "...",
  "userID": "...",
  "fullName": "Max Mustermann"
}
```

4. **[Backend <-> Apple PK server]** Validates JWT-Signature against Apple Public Keys; extracts claims (`userID`, `email`, ...)
5. **[Backend <-> Apple]** Exchanges `authorizationCode` for `accessToken` / `refreshToken` from Apple
6. **[Backend -> Client]** Saves user; Returns own `sessionToken`

> Notice: `fullName` will only be provided when signing in for the first time - `userID` remains stable for AppID even after deleting SIWA credentials.

# Credis

## Especially helpful Resources

- Example code for SIWA from [Github: Timothylock/go-signin-with-apple](https://github.com/Timothylock/go-signin-with-apple?tab=readme-ov-file)
- Example code for APNs from [matheus-vb/APNs-go](https://github.com/matheus-vb/APNs-go/tree/main/util)
- Example code for OAuth2 via Goth from [syahriarreza/go-simple-oauth2](https://github.com/syahriarreza/go-simple-oauth2)
- Example code for setting up Goth from [Github: Package Goth](https://github.com/markbates/goth/blob/master/examples/main.go)

## Understanding

- Tutorial for implementing SIWA (with Appwrite): [YT: Sign in with Apple OAuth2 tutorial](https://www.youtube.com/watch?v=8v01TaX1EJA&t=453s)
- Tutorial for implementing Sign in with Google (with Golang): [YT: The BEST OAuth Golang Tutorial for Authentication | Sign In With Google](https://www.youtube.com/watch?v=iHFQyd__2A0)
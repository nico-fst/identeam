# IdenTEAM

Start your habit challenge now - elevate your **iden**tity as a **TEAM**!

# Dev Setup

## Setup

- Create `.env` (like `.example.env`) with values from Apple Developer
- Insert `/backend/apns_key.p8` (created as Key for APNs on Apple Developer)

After installing packages with `go mod tidy`, the server can now be started via `go run main.go`.

# Credis and Resources

- Working example code for APNs from [matheus-vb/APNs-go](https://github.com/matheus-vb/APNs-go/tree/main/util)
- Working example code for OAuth2 via Goth from [syahriarreza/go-simple-oauth2](https://github.com/syahriarreza/go-simple-oauth2)
- Tutorial for implementing SIWA (with Appwrite): [YT: Sign in with Apple OAuth2 tutorial](https://www.youtube.com/watch?v=8v01TaX1EJA&t=453s)
- Tutorial for implementing Sign in with Google: [YT: The BEST OAuth Golang Tutorial for Authentication | Sign In With Google](https://www.youtube.com/watch?v=iHFQyd__2A0)
- Example for setting up Goth from [Github: Package Goth](https://github.com/markbates/goth/blob/master/examples/main.go)
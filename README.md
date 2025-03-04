# Docker setup for running an untrusted application in ubuntu

Put a CLI I'm not familiar with in untrusted_app folder

The home dir will be persisted in `container_home`

Netowrk traffic logged to `network_logs`

Usage:

`docker build -t untrusted-app .`
`./run.sh bash`
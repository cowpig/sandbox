# Ubuntu Sandbox

This is a docker setup for running an untrusted application in ubuntu

The home dir will be persisted in `container_home`

Netowrk traffic logged to `network_logs`

Usage:

`docker build -t untrusted-app .`

`./run.sh bash`
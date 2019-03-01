#!/bin/sh

SERVER="root@51.15.211.123"

cd server
env GOARCH=amd64 GOOS=linux go build -o=ccserver-linux *.go
cd ..

rsync -av --delete ./server $SERVER:~/
rsync -av --delete ./data $SERVER:~/
rm ./server/ccserver-linux

# 'cd ~/server && ./ccserver-linux -cfg=config-production &'

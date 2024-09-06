#!/bin/sh
    
# This script requires GITEA_DOMAIN_NAME & DOMAIN_NAME variable to be created already
# GITEA_DOMAIN_NAME is the domain name of the Gitea instance
# DOMAIN_NAME is the domain name of the cluster
# Example: GITEA_DOMAIN_NAME=gitea.example.com 
# DOMAIN_NAME=example.com

echo "Creating app repositories in gitea"
apk add gitea
apk add git
apk add openssh-client

cd ../../applications   #TODO: adjust this according to where this script is finally placed

PASSWORD=$(kubectl get secret gitea-credential -n gitea -o jsonpath='{.data.password}' | base64 --decode)
USERNAME=$(kubectl get secret gitea-credential -n gitea -o jsonpath='{.data.username}' | base64 --decode)
USER_PASS="${USERNAME}:${PASSWORD}"
ENCODED_USER_PASS=$(echo -n "${USER_PASS}" | base64)

curl -k -X POST "https://$GITEA_DOMAIN_NAME/api/v1/admin/users/giteaAdmin/repos" -H "content-type: application/json" -H "Authorization: Basic $ENCODED_USER_PASS" --data '{"name":"dotnet"}'
curl -k -X POST "https://$GITEA_DOMAIN_NAME/api/v1/admin/users/giteaAdmin/repos" -H "content-type: application/json" -H "Authorization: Basic $ENCODED_USER_PASS" --data '{"name":"golang"}'
curl -k -X POST "https://$GITEA_DOMAIN_NAME/api/v1/admin/users/giteaAdmin/repos" -H "content-type: application/json" -H "Authorization: Basic $ENCODED_USER_PASS" --data '{"name":"java"}'

git config --global user.email "git@gitea.com"
git config --global user.name $USERNAME

cd dotnet 
git init
git checkout -b main
git add .
git commit -m "first commit"
git remote add origin git@$DOMAIN_NAME/giteaAdmin/golang.git
git push -u origin main

cd ..
cd golang 
git init
git checkout -b main
git add .
git commit -m "first commit"
git remote add origin git@$DOMAIN_NAME/giteaAdmin/golang.git
git push -u origin main

cd ..
cd java 
git init
git checkout -b main
git add .
git commit -m "first commit"
git remote add origin git$DOMAIN_NAME/giteaAdmin/java.git
git push -u origin main
exit 0
# Native browser

##
┌─────────────────────┐
│ selenium/standalone │  ← Container independente
│   (chromedriver)    │     Expõe API WebDriver na porta 9515
│   Port: 9515        │
└─────────────────────┘
         ↑ HTTP
         │ "abra site X, clique botão Y"
         │
    ┌────┴─────┬──────────┬──────────┐
    │          │          │          │
┌───┴───┐  ┌───┴───┐  ┌───┴───┐  ┌───┴───┐
│tenant1│  │tenant2│  │tenant3│  │tenant4│  ← Containers ZeroClaw
│ 50MB  │  │ 50MB  │  │ 50MB  │  │ 50MB  │     Usam chromedriver via HTTP
└───────┘  └───────┘  └───────┘  └───────┘

## Build the native browser image no VPS via SSH
cd /opt/zeroclaw
docker build -f Dockerfile.native-browser -t zeroclaw-native-browser:latest --target release .

## Start shared chromedriver
docker run -d --name chromedriver -p 9515:4444 selenium/standalone-chrome:latest

## Update tenant setup to use new image

Edit setup-tenant.sh line with ZEROCLAW_IMAGE to use zeroclaw-native-browser:latest



.coderabbit.yaml         .git/                    .markdownlint-cli2.yaml  
edgar@srv978843:~/Repos/zeroclaw$ docker  images
REPOSITORY                         TAG          IMAGE ID       CREATED          SIZE
zeroclaw-native-browser            latest       2ccb5696ec6e   46 seconds ago   37MB
ghcr.io/theonlyhennygod/zeroclaw   latest       ee68e2a43bd7   2 days ago       30.3MB

cd edgar/
docker compose down
docker compose rm -f
ZEROCLAW_IMAGE=zeroclaw-native-browser:latest
docker compose up -d --force-recreate
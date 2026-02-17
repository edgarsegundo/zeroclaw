# Como usar:

## 1. Criar o script de setup
cd /opt/zeroclaw
vim setup-tenant.sh  # Cole o conteúdo acima
chmod +x setup-tenant.sh

## 2. Criar tenants
./setup-tenant.sh edgar 3001
./setup-tenant.sh tenant2 3002
./setup-tenant.sh tenant3 3003

## 3. Configurar cada tenant
vim /opt/zeroclaw/edgar/.env  # Adicione API_KEY e TELEGRAM_BOT_TOKEN

## 4. Iniciar cada tenant
cd /opt/zeroclaw/edgar
docker-compose up -d

cd /opt/zeroclaw/tenant2
docker-compose up -d

## 5. Verificar status
docker ps
curl http://localhost:3001/health
curl http://localhost:3002/health

## 6. Acessar configs diretamente no host
vim /opt/zeroclaw/edgar/data/.zeroclaw/config.toml
cat /opt/zeroclaw/edgar/data/workspace/session.log

## 7. Fazer pairing para cada tenant
cd /opt/zeroclaw/edgar
docker-compose exec zeroclaw zeroclaw pair
## Copie o token e use no Telegram bot


## Gerenciar todos os tenants:

### Ver todos os containers
docker ps -a | grep zeroclaw

### Parar todos
cd /opt/zeroclaw/edgar && docker-compose down
cd /opt/zeroclaw/tenant2 && docker-compose down

### Reiniciar todos
cd /opt/zeroclaw/edgar && docker-compose restart
cd /opt/zeroclaw/tenant2 && docker-compose restart

### Ver logs
docker logs zeroclaw-edgar -f
docker logs zeroclaw-tenant2 -f
# Como usar:

## 1. Criar tenants

./setup-tenant.sh daniela 3002

## 2. Configurar cada tenant

nano /opt/zeroclaw/edgar/.env  # Adicione API_KEY e TELEGRAM_BOT_TOKEN

## 3. Iniciar cada tenant

cd /opt/zeroclaw/daniela
docker compose up -d

## 4. Verificar status

docker ps
curl http://localhost:3001/health

## 5. Acessar configs diretamente no host

vim /opt/zeroclaw/edgar/data/.zeroclaw/config.toml
cat /opt/zeroclaw/edgar/data/workspace/session.log

## 6. Fazer pairing para cada tenant
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
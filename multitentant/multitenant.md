# How to set up zeroclaw as multitenant

## Problema com permissão porque /data é criado com root, precisa dar permissão para container:

sudo chown -R 65534:65534 /opt/zeroclaw/edgar/data


docker compose up -d


# Editar config diretamente no host
sudo nano /opt/zeroclaw/edgar/data/.zeroclaw/config.toml

## Perfeito! Agora você precisa mudar duas coisas:

[gateway]
port = 3000
host = "[::]"                    # ← Mude de 127.0.0.1 para [::]
require_pairing = true
allow_public_bind = true         # ← Mude de false para true
paired_tokens = []
pair_rate_limit_per_minute = 10
webhook_rate_limit_per_minute = 60
idempotency_ttl_secs = 300



## Próximo passo: Fazer pairing

# 1. Fazer pairing (vai gerar um novo código)
docker logs zeroclaw-edgar | grep -A 5 "PAIRING REQUIRED"


curl -X POST http://localhost:3001/pair \
  -H "X-Pairing-Code: 279537"



## Testar o webhook:
curl -X POST http://localhost:3001/webhook \
  -H "Authorization: Bearer zc_SEU_TOKEN_AQUI" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello ZeroClaw!"}'


## 2. Configurar Telegram (se quiser):
Edite o config:
sudo nano /opt/zeroclaw/edgar/data/.zeroclaw/config.toml

[[channels]]
type = "telegram"
bot_token = "SEU_TELEGRAM_BOT_TOKEN"
allowed_users = []  # ou adicione IDs permitidos




cd /opt/zeroclaw/edgar
docker compose restart



# Ver logs em tempo real
docker logs zeroclaw-edgar -f

# Ver últimas 100 linhas
docker logs zeroclaw-edgar --tail 100

# Ver logs com timestamp
docker logs zeroclaw-edgar -f --timestamps











## VPN Tailscale

Você NÃO precisa de Tailscale se:
✅ Você vai usar apenas via Telegram/Discord/Slack (bots públicos)
✅ Você quer webhook público com pairing/autenticação (já tem)
✅ Você confia no pairing token como barreira de segurança
✅ Você vai usar reverse proxy com TLS (Nginx + Let's Encrypt)

Nesse caso: Exponha a porta 3001 com firewall + rate limiting e está ok.
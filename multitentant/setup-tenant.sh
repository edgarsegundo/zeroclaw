#!/bin/bash
# Script para criar um novo tenant

TENANT_NAME=$1
PORT=$2

if [ -z "$TENANT_NAME" ] || [ -z "$PORT" ]; then
    echo "Uso: ./setup-tenant.sh <tenant_name> <port>"
    echo "Exemplo: ./setup-tenant.sh edgar 3001"
    exit 1
fi

TENANT_DIR="/opt/zeroclaw/${TENANT_NAME}"

# Criar estrutura de diretórios
mkdir -p "${TENANT_DIR}/data/.zeroclaw"
mkdir -p "${TENANT_DIR}/data/workspace"

# Criar .env
cat > "${TENANT_DIR}/.env" << EOF
# Tenant: ${TENANT_NAME}
API_KEY=your_api_key_here
PROVIDER=openai
ZEROCLAW_MODEL=gpt-4o-mini
HOST_PORT=${PORT}
TELEGRAM_BOT_TOKEN=
ZEROCLAW_IMAGE=ghcr.io/theonlyhennygod/zeroclaw:latest
EOF

# Criar docker-compose.yml
cat > "${TENANT_DIR}/docker-compose.yml" << 'EOF'
# ZeroClaw - Tenant: TENANT_NAME
# Port: PORT

services:
  zeroclaw:
    image: ${ZEROCLAW_IMAGE:-ghcr.io/theonlyhennygod/zeroclaw:latest}
    container_name: zeroclaw-TENANT_NAME
    restart: unless-stopped
    
    environment:
      - API_KEY=${API_KEY}
      - PROVIDER=${PROVIDER:-openrouter}
      - ZEROCLAW_MODEL=${ZEROCLAW_MODEL:-anthropic/claude-sonnet-4-20250514}
      - ZEROCLAW_ALLOW_PUBLIC_BIND=true
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
      
    volumes:
      - ./data:/zeroclaw-data
      
    ports:
      - "${HOST_PORT:-PORT}:3000"
    
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M

    healthcheck:
      test: ["CMD", "zeroclaw", "doctor"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
EOF

# Substituir placeholders
sed -i "s/TENANT_NAME/${TENANT_NAME}/g" "${TENANT_DIR}/docker-compose.yml"
sed -i "s/PORT/${PORT}/g" "${TENANT_DIR}/docker-compose.yml"

# Ajustar permissões (user 65534 = nobody no container)
chown -R 65534:65534 "${TENANT_DIR}/data"

echo "✅ Tenant '${TENANT_NAME}' criado em ${TENANT_DIR}"
echo ""
echo "🔑 Configuração de API Key"
echo "----------------------------------------"
read -p "Digite sua API Key (OpenAI/OpenRouter): " API_KEY_INPUT

if [ -z "$API_KEY_INPUT" ]; then
    echo "⚠️  Nenhuma API key fornecida. Você precisará editar manualmente:"
    echo "   ${TENANT_DIR}/.env"
else
    # Atualizar .env com a API key fornecida
    sed -i "s|API_KEY=your_api_key_here|API_KEY=${API_KEY_INPUT}|" "${TENANT_DIR}/.env"
    echo "✅ API Key configurada!"
fi

echo ""
read -p "Digite o token do Telegram Bot (ou Enter para pular): " TELEGRAM_TOKEN_INPUT

if [ -n "$TELEGRAM_TOKEN_INPUT" ]; then
    sed -i "s|TELEGRAM_BOT_TOKEN=|TELEGRAM_BOT_TOKEN=${TELEGRAM_TOKEN_INPUT}|" "${TENANT_DIR}/.env"
    echo "✅ Token do Telegram configurado!"
fi

echo ""
echo "🚀 Inicie com: cd ${TENANT_DIR} && docker compose up -d"

echo "📝 Edite ${TENANT_DIR}/data/.zeroclaw/config.toml para configurar o tenant"
echo ""
echo "⚠️  ATENÇÃO"
echo "----------------------------------------"
echo "Atualize o config.toml do tenant:"
echo ""
echo "[gateway]"
echo "  host = \"[::]\""
echo "  allow_public_bind = true"
echo ""
echo "# Modelo"
echo "  default_provider = \"openai\""
echo "  default_model = \"gpt-4o-mini\""
echo ""
echo "Depois execute:"
echo "  docker compose restart"
echo ""
echo "Verifique os logs para o status de emparelhamento:"
echo "  docker logs zeroclaw-${TENANT_NAME} | grep -A 5 \"PAIRING REQUIRED\""

echo ""
echo "⏳ Aguardando código de pareamento..."

# # Captura o código (6 dígitos) dos logs em tempo real
# PAIRING_CODE=$(timeout 60 docker logs -f zeroclaw-${TENANT_NAME} 2>&1 | grep -m1 -oE '[0-9]{6}')

# if [ -z "$PAIRING_CODE" ]; then
#     echo "❌ Não foi possível obter o código de pareamento."
#     echo "Verifique manualmente com:"
#     echo "  docker logs zeroclaw-${TENANT_NAME} | grep -A 5 \"PAIRING REQUIRED\""
# else
#     echo "✅ Código de pareamento encontrado: $PAIRING_CODE"
#     echo "🔗 Enviando requisição de pareamento..."

#     curl -X POST "http://localhost:${PORT}/pair" \
#       -H "X-Pairing-Code: $PAIRING_CODE"

#     echo ""
#     echo "✅ Pareamento concluído!"
# fi
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

# Criar docker compose.yml
cat > "${TENANT_DIR}/docker compose.yml" << 'EOF'
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
sed -i "s/TENANT_NAME/${TENANT_NAME}/g" "${TENANT_DIR}/docker compose.yml"
sed -i "s/PORT/${PORT}/g" "${TENANT_DIR}/docker compose.yml"

# Ajustar permissões (user 65534 = nobody no container)
chown -R 65534:65534 "${TENANT_DIR}/data"

echo "✅ Tenant '${TENANT_NAME}' criado em ${TENANT_DIR}"
echo "📝 Edite ${TENANT_DIR}/.env para configurar API keys"
echo ""

# Iniciar container
echo "🚀 Iniciando container..."
cd "${TENANT_DIR}" && docker compose up -d

echo ""
echo "⏳ Aguardando container inicializar (5s)..."
sleep 5

echo ""
echo "=========================================="
echo " Iniciando processo de pairing..."
echo "=========================================="
echo ""

# Chamar o script de pairing (volta para o diretório do script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}" && ./pair-tenant.sh

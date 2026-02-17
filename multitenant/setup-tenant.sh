#!/bin/bash
# Script para criar um novo tenant

# Verifica se está rodando como root/sudo
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script precisa ser executado com sudo"
    echo "Uso: sudo ./setup-tenant.sh <tenant_name> <port>"
    exit 1
fi

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
echo "⚙️  Configuração do Gateway"
echo "----------------------------------------"
read -p "Provider [openai]: " PROVIDER_INPUT
PROVIDER_INPUT=${PROVIDER_INPUT:-openai}

read -p "Modelo [gpt-4o-mini]: " MODEL_INPUT
MODEL_INPUT=${MODEL_INPUT:-gpt-4o-mini}

read -p "Gateway host [[::]]: " HOST_INPUT
HOST_INPUT=${HOST_INPUT:-[::]}

read -p "Allow public bind? [true]: " ALLOW_PUBLIC_INPUT
ALLOW_PUBLIC_INPUT=${ALLOW_PUBLIC_INPUT:-true}

echo ""
echo "� Iniciando container..."
cd "${TENANT_DIR}" && docker compose up -d

echo "⏳ Aguardando container criar config.toml (15s)..."
sleep 15

CONFIG_FILE="${TENANT_DIR}/data/.zeroclaw/config.toml"

# Verificar se o config foi criado
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  config.toml ainda não foi criado. Aguardando mais 10s..."
    sleep 10
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ config.toml não foi criado pelo container."
    echo "Verifique os logs: docker logs zeroclaw-${TENANT_NAME}"
    exit 1
fi

echo "✅ config.toml encontrado!"
echo "📝 Atualizando configurações..."

# Atualizar configurações no config.toml
sed -i "s|^api_key = .*|api_key = \"${API_KEY_INPUT:-}\"|" "$CONFIG_FILE"
sed -i "s|^default_provider = .*|default_provider = \"${PROVIDER_INPUT}\"|" "$CONFIG_FILE"
sed -i "s|^default_model = .*|default_model = \"${MODEL_INPUT}\"|" "$CONFIG_FILE"
sed -i "s|^host = .*|host = \"${HOST_INPUT}\"|" "$CONFIG_FILE"
sed -i "s|^allow_public_bind = .*|allow_public_bind = ${ALLOW_PUBLIC_INPUT}|" "$CONFIG_FILE"

echo "✅ config.toml atualizado com sucesso!"
echo ""
echo "🔄 Reiniciando container para aplicar configurações..."
docker compose restart

echo "⏳ Aguardando container reiniciar (5s)..."
sleep 5

echo "✅ Container reiniciado!"
echo ""
echo "=========================================="
echo " Iniciando processo de pairing..."
echo "=========================================="
echo ""

# Chamar o script de pairing (volta para o diretório do script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}" && ./pair-tenant.sh "${TENANT_NAME}" "${PORT}"
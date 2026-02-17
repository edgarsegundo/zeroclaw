#!/bin/bash
# Script para parear um tenant automaticamente

TENANT_NAME=$1
PORT=$2

if [ -z "$TENANT_NAME" ] || [ -z "$PORT" ]; then
    echo "Uso: ./pair-tenant.sh <tenant_name> <port>"
    echo "Exemplo: ./pair-tenant.sh edgar 3001"
    exit 1
fi

CONTAINER="zeroclaw-${TENANT_NAME}"

echo "🔍 Buscando código de pareamento para o tenant '${TENANT_NAME}'..."
echo ""

# Aguarda código nos logs (até 60s)
PAIRING_CODE=$(timeout 60 docker logs -f "$CONTAINER" 2>&1 | grep -m1 -oE '[0-9]{6}')

if [ -z "$PAIRING_CODE" ]; then
    echo "❌ Não foi possível encontrar o código automaticamente."
    echo ""
    echo "Tente manualmente:"
    echo "docker logs $CONTAINER | grep -A 5 \"PAIRING REQUIRED\""
    exit 1
fi

echo "✅ Código encontrado: $PAIRING_CODE"
echo ""

echo "🔗 Enviando requisição de pareamento..."

RESPONSE=$(curl -s -X POST "http://localhost:${PORT}/pair" \
  -H "X-Pairing-Code: $PAIRING_CODE")

echo ""
echo "📡 Resposta:"
echo "$RESPONSE"
echo ""

echo "✅ Processo finalizado!"

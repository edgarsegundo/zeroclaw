#!/bin/bash

BASE_DIR="/opt/zeroclaw"

# Verifica se o diretório existe
if [ ! -d "$BASE_DIR" ]; then
    echo "❌ Diretório $BASE_DIR não encontrado"
    exit 1
fi

# Lista tenants
echo "Selecione um tenant:"
echo ""

tenants=($(ls -1 "$BASE_DIR"))

if [ ${#tenants[@]} -eq 0 ]; then
    echo "❌ Nenhum tenant encontrado em $BASE_DIR"
    exit 1
fi

# Mostrar lista numerada
for i in "${!tenants[@]}"; do
    echo "$((i+1))) ${tenants[$i]}"
done

echo ""
read -p "Digite o número do tenant: " choice

# Validar escolha
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#tenants[@]} ]; then
    echo "❌ Opção inválida"
    exit 1
fi

TENANT_NAME="${tenants[$((choice-1))]}"
TENANT_DIR="$BASE_DIR/$TENANT_NAME"
ENV_FILE="$TENANT_DIR/.env"
CONTAINER="zeroclaw-$TENANT_NAME"

echo ""
echo "👉 Tenant selecionado: $TENANT_NAME"

# Verifica .env
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Arquivo .env não encontrado em $TENANT_DIR"
    exit 1
fi

# Extrai a porta
PORT=$(grep "^HOST_PORT=" "$ENV_FILE" | cut -d '=' -f2)

if [ -z "$PORT" ]; then
    echo "❌ HOST_PORT não encontrado no .env"
    exit 1
fi

echo "🌐 Porta detectada: $PORT"
echo ""

echo "⏳ Buscando código de pareamento..."

# Captura código
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

echo "🔗 Enviando requisição..."

RESPONSE=$(curl -s -X POST "http://localhost:$PORT/pair" \
  -H "X-Pairing-Code: $PAIRING_CODE")

echo ""
echo "📡 Resposta:"
echo "$RESPONSE"
echo ""

echo "✅ Pareamento concluído!"

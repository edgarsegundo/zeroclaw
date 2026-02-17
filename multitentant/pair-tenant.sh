#!/bin/bash

BASE_DIR="/opt/zeroclaw"

echo "========================================"
echo " ZeroClaw - Pairing Tool"
echo "========================================"
echo ""

# Verifica diretório base
if [ ! -d "$BASE_DIR" ]; then
    echo "❌ Diretório $BASE_DIR não encontrado"
    exit 1
fi

# Lista tenants válidos (com .env)
tenants=()
for dir in "$BASE_DIR"/*; do
    [ -d "$dir" ] && [ -f "$dir/.env" ] && tenants+=("$(basename "$dir")")
done

if [ ${#tenants[@]} -eq 0 ]; then
    echo "❌ Nenhum tenant válido encontrado em $BASE_DIR"
    exit 1
fi

# Mostrar lista
echo "Selecione um tenant:"
echo ""

for i in "${!tenants[@]}"; do
    echo "$((i+1))) ${tenants[$i]}"
done

echo ""
read -p "Digite o número do tenant: " choice

# Validar entrada
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
    echo "❌ Arquivo .env não encontrado"
    exit 1
fi

# Extrai porta
PORT=$(grep "^HOST_PORT=" "$ENV_FILE" | cut -d '=' -f2)

if [ -z "$PORT" ]; then
    echo "❌ HOST_PORT não encontrado no .env"
    exit 1
fi

echo "🌐 Porta: $PORT"
echo ""

# Verifica token existente
EXISTING_TOKEN=$(grep "^ZEROCLAW_TOKEN=" "$ENV_FILE" | cut -d '=' -f2)

if [ -n "$EXISTING_TOKEN" ]; then
    echo "✅ Tenant já está pareado."
    echo "🔑 Token: $EXISTING_TOKEN"
    echo ""

    echo "🚀 Testando webhook..."

    curl -s -X POST "http://localhost:$PORT/webhook" \
      -H "Authorization: Bearer $EXISTING_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"message": "Hello again!"}'

    echo ""
    echo "✅ Teste concluído!"
    exit 0
fi

# Verifica se container precisa de pairing
echo "⏳ Verificando status do pairing..."

# Busca nos logs recentes (últimas 50 linhas)
LOGS=$(docker logs --tail 50 "$CONTAINER" 2>&1)

# Verifica se já está pareado
if echo "$LOGS" | grep -q "🔒 Pairing: ACTIVE (bearer token required)"; then
    echo "⚠️  Container já está pareado, mas token não está no .env"
    echo ""
    echo "Opções:"
    echo "1. Pegue o token do config.toml:"
    echo "   sudo cat $TENANT_DIR/data/.zeroclaw/config.toml | grep paired_tokens"
    echo ""
    echo "2. Ou reinicie o container para gerar novo código de pairing:"
    echo "   cd $TENANT_DIR && docker-compose restart"
    exit 1
fi

# Verifica se pairing está desabilitado
if echo "$LOGS" | grep -q "⚠️  Pairing: DISABLED"; then
    echo "⚠️  Pairing está desabilitado para este tenant"
    echo "Nenhum token necessário."
    exit 0
fi

# Busca código de pairing nos logs
PAIRING_CODE=$(echo "$LOGS" | grep -A 3 "PAIRING REQUIRED" | grep -oE '[0-9]{6}' | head -n1)

if [ -z "$PAIRING_CODE" ]; then
    echo "❌ Código de pairing não encontrado nos logs."
    echo ""
    echo "🔄 Reiniciando container para gerar novo código..."
    cd "$TENANT_DIR" && docker-compose restart > /dev/null 2>&1
    
    echo "⏳ Aguardando container iniciar (10s)..."
    sleep 10
    
    # Busca novo código
    PAIRING_CODE=$(docker logs --tail 50 "$CONTAINER" 2>&1 | grep -A 3 "PAIRING REQUIRED" | grep -oE '[0-9]{6}' | head -n1)
    
    if [ -z "$PAIRING_CODE" ]; then
        echo "❌ Ainda não foi possível obter o código."
        echo ""
        echo "Para ver os logs manualmente:"
        echo "docker logs $CONTAINER | grep -A 5 \"PAIRING REQUIRED\""
        exit 1
    fi
fi

echo "✅ Código encontrado: $PAIRING_CODE"
echo ""

# Pequena pausa para garantir que o endpoint está pronto
sleep 2

echo "🔗 Enviando pareamento..."

RESPONSE=$(curl -s -X POST "http://localhost:$PORT/pair" \
  -H "X-Pairing-Code: $PAIRING_CODE")

# Se o pairing falhar por código inválido, tenta reiniciar e gerar novo código
if echo "$RESPONSE" | grep -q "Invalid pairing code"; then
    echo "⚠️  Código inválido (já foi usado). Gerando novo código..."
    echo ""
    
    OLD_CODE="$PAIRING_CODE"
    
    # Para e inicia novamente (down/up gera novo código com certeza)
    cd "$TENANT_DIR" && docker-compose down > /dev/null 2>&1
    echo "⏳ Iniciando container e aguardando novo código (15s)..."
    docker-compose up -d > /dev/null 2>&1
    sleep 15
    
    # Busca novo código (deve ser diferente)
    for i in {1..5}; do
        PAIRING_CODE=$(docker logs --tail 20 "$CONTAINER" 2>&1 | grep -A 3 "PAIRING REQUIRED" | grep -oE '[0-9]{6}' | tail -n1)
        
        # Verifica se é um código diferente
        if [ -n "$PAIRING_CODE" ] && [ "$PAIRING_CODE" != "$OLD_CODE" ]; then
            break
        fi
        
        echo "⏳ Aguardando código diferente... tentativa $i/5"
        sleep 3
    done
    
    if [ -z "$PAIRING_CODE" ] || [ "$PAIRING_CODE" = "$OLD_CODE" ]; then
        echo "❌ Não foi possível obter novo código único."
        echo "Código antigo: $OLD_CODE"
        echo "Código atual: $PAIRING_CODE"
        echo ""
        echo "Tente manualmente:"
        echo "1. cd $TENANT_DIR"
        echo "2. docker-compose down && docker-compose up -d"
        echo "3. docker logs $CONTAINER | grep -A 5 'PAIRING REQUIRED'"
        exit 1
    fi
    
    echo "✅ Novo código encontrado: $PAIRING_CODE"
    echo ""
    
    sleep 2
    
    echo "🔗 Tentando pareamento novamente..."
    RESPONSE=$(curl -s -X POST "http://localhost:$PORT/pair" \
      -H "X-Pairing-Code: $PAIRING_CODE")
fi

echo ""
echo "📡 Resposta:"
echo "$RESPONSE"
echo ""

# Extrair token
TOKEN=$(echo "$RESPONSE" | grep -oP '"token":"\K[^"]+')

if [ -z "$TOKEN" ]; then
    echo "❌ Não foi possível extrair o token"
    exit 1
fi

echo "🔑 Token obtido:"
echo "$TOKEN"
echo ""

# Salvar token no .env
if grep -q "^ZEROCLAW_TOKEN=" "$ENV_FILE"; then
    sed -i "s|^ZEROCLAW_TOKEN=.*|ZEROCLAW_TOKEN=$TOKEN|" "$ENV_FILE"
else
    echo "ZEROCLAW_TOKEN=$TOKEN" >> "$ENV_FILE"
fi

echo "💾 Token salvo em $ENV_FILE"
echo ""

# Reiniciar container
echo "🔄 Reiniciando container..."
cd "$TENANT_DIR" && docker-compose restart
echo ""

# Testar webhook
echo "🚀 Enviando mensagem de teste..."

WEBHOOK_RESPONSE=$(curl -s -X POST "http://localhost:$PORT/webhook" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello ZeroClaw!"}')

echo ""
echo "📨 Resposta do webhook:"
echo "$WEBHOOK_RESPONSE"
echo ""

echo "========================================"
echo " ✅ Pairing concluído com sucesso!"
echo "========================================"
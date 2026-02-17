#!/bin/bash

BASE_DIR="/opt/zeroclaw"

echo "========================================"
echo " ZeroClaw - Pairing Tool"
echo "========================================"
echo ""

echo "🔍 [DEBUG] Verificando diretório base: $BASE_DIR"
# Verifica diretório base
if [ ! -d "$BASE_DIR" ]; then
    echo "❌ Diretório $BASE_DIR não encontrado"
    exit 1
fi
echo "✅ [DEBUG] Diretório base encontrado"

echo ""
echo "🔍 [DEBUG] Parâmetros recebidos: \$1='$1' \$2='$2'"

# Se parâmetros foram passados, usa eles diretamente
if [ -n "$1" ] && [ -n "$2" ]; then
    echo "✅ [DEBUG] Modo automático: usando parâmetros fornecidos"
    TENANT_NAME="$1"
    PORT="$2"
    TENANT_DIR="$BASE_DIR/$TENANT_NAME"
    ENV_FILE="$TENANT_DIR/.env"
    CONTAINER="zeroclaw-$TENANT_NAME"
    
    echo "👉 Tenant: $TENANT_NAME"
    echo "🌐 Porta: $PORT"
    echo "📂 [DEBUG] TENANT_DIR: $TENANT_DIR"
    echo "📄 [DEBUG] ENV_FILE: $ENV_FILE"
    echo "🐳 [DEBUG] CONTAINER: $CONTAINER"
    echo ""
    
    # Verifica se o tenant existe
    echo "🔍 [DEBUG] Verificando se tenant existe..."
    if [ ! -d "$TENANT_DIR" ]; then
        echo "❌ [DEBUG] TENANT_DIR não existe: $TENANT_DIR"
        exit 1
    fi
    if [ ! -f "$ENV_FILE" ]; then
        echo "❌ [DEBUG] ENV_FILE não existe: $ENV_FILE"
        exit 1
    fi
    echo "✅ [DEBUG] Tenant existe"
else
    echo "✅ [DEBUG] Modo interativo: listando tenants"
    # Modo interativo: lista tenants válidos
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
    
    echo "🔍 [DEBUG] Extraindo porta do .env..."
    # Extrai porta do .env
    PORT=$(grep "^HOST_PORT=" "$ENV_FILE" | cut -d '=' -f2)
    
    if [ -z "$PORT" ]; then
        echo "❌ HOST_PORT não encontrado no .env"
        exit 1
    fi
    
    echo "🌐 Porta: $PORT"
    echo ""
fi

echo "🔍 [DEBUG] Verificando .env: $ENV_FILE"
# Verifica .env
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Arquivo .env não encontrado"
    exit 1
fi
echo "✅ [DEBUG] .env encontrado"

echo ""
echo "🔍 [DEBUG] Verificando token existente..."
# Verifica token existente
EXISTING_TOKEN=$(grep "^ZEROCLAW_TOKEN=" "$ENV_FILE" | cut -d '=' -f2)

echo ""
echo "🔍 [DEBUG] Verificando token existente..."
# Verifica token existente
EXISTING_TOKEN=$(grep "^ZEROCLAW_TOKEN=" "$ENV_FILE" | cut -d '=' -f2)

if [ -n "$EXISTING_TOKEN" ]; then
    echo "✅ Tenant já está pareado."
    echo "🔑 Token: $EXISTING_TOKEN"
    echo ""

    echo "🚀 Testando webhook..."
    echo "🔍 [DEBUG] URL: http://localhost:$PORT/webhook"

    WEBHOOK_TEST=$(curl -s -X POST "http://localhost:$PORT/webhook" \
      -H "Authorization: Bearer $EXISTING_TOKEN" \
      -H "Content-Type: application/json" \
      -d '{"message": "Hello again!"}')
    
    echo "$WEBHOOK_TEST"
    echo ""
    echo "✅ Teste concluído!"
    exit 0
fi
echo "🔍 [DEBUG] Nenhum token existente encontrado, continuando..."

echo ""
echo "🔍 [DEBUG] Verificando status do container..."
# Verifica se container precisa de pairing
echo "⏳ Verificando status do pairing..."

# Busca nos logs recentes (últimas 100 linhas para garantir)
echo "🔍 [DEBUG] Buscando logs do container: $CONTAINER"
LOGS=$(docker logs --tail 100 "$CONTAINER" 2>&1)
echo "🔍 [DEBUG] Logs obtidos (primeiras 300 chars): ${LOGS:0:300}"

# Verifica se já está pareado
if echo "$LOGS" | grep -q "🔒 Pairing: ACTIVE (bearer token required)"; then
    echo "⚠️  Container já está pareado, mas token não está no .env"
    echo ""
    echo "Opções:"
    echo "1. Pegue o token do config.toml:"
    echo "   sudo cat $TENANT_DIR/data/.zeroclaw/config.toml | grep paired_tokens"
    echo ""
    echo "2. Ou reinicie o container para gerar novo código de pairing:"
    echo "   cd $TENANT_DIR && docker compose restart"
    exit 1
fi

# Verifica se pairing está desabilitado
if echo "$LOGS" | grep -q "⚠️  Pairing: DISABLED"; then
    echo "⚠️  Pairing está desabilitado para este tenant"
    echo "Nenhum token necessário."
    exit 0
fi

# Busca código de pairing nos logs (do fim para o início, pega o mais recente)
echo "🔍 [DEBUG] Buscando código de pairing nos logs..."
PAIRING_CODE=$(echo "$LOGS" | grep -A 3 "PAIRING REQUIRED" | grep -oE '[0-9]{6}' | tail -n1)
echo "🔍 [DEBUG] Código encontrado: '$PAIRING_CODE'"

if [ -z "$PAIRING_CODE" ]; then
    echo "❌ Código de pairing não encontrado nos logs."
    echo ""
    echo "🔄 Reiniciando container para gerar novo código..."
    echo "🔍 [DEBUG] Executando: cd $TENANT_DIR && docker compose restart"
    cd "$TENANT_DIR" && docker compose restart > /dev/null 2>&1
    
    echo "⏳ Aguardando container iniciar (10s)..."
    sleep 10
    
    echo "🔍 [DEBUG] Buscando novo código após restart..."
    # Busca novo código (do fim para o início)
    PAIRING_CODE=$(docker logs --tail 100 "$CONTAINER" 2>&1 | grep -A 3 "PAIRING REQUIRED" | grep -oE '[0-9]{6}' | tail -n1)
    echo "🔍 [DEBUG] Novo código: '$PAIRING_CODE'"
    
    if [ -z "$PAIRING_CODE" ]; then
        echo "❌ Ainda não foi possível obter o código."
        echo ""
        echo "Verificando se o container está rodando..."
        if ! docker ps | grep -q "$CONTAINER"; then
            echo "❌ Container não está rodando!"
            echo "Verifique os logs: docker logs $CONTAINER"
            exit 1
        fi
        echo "Para ver os logs manualmente:"
        echo "docker logs $CONTAINER | grep -A 5 \"PAIRING REQUIRED\""
        exit 1
    fi
fi

echo "✅ Código encontrado: $PAIRING_CODE"
echo ""

# Pequena pausa para garantir que o endpoint está pronto
echo "🔍 [DEBUG] Aguardando 2s para endpoint estar pronto..."
sleep 2

echo "🔗 Enviando pareamento..."
echo "🔍 [DEBUG] URL: http://localhost:$PORT/pair"
echo "🔍 [DEBUG] Código: $PAIRING_CODE"

RESPONSE=$(curl -s -X POST "http://localhost:$PORT/pair" \
  -H "X-Pairing-Code: $PAIRING_CODE")

echo "🔍 [DEBUG] Resposta do pairing:"
echo "$RESPONSE"

# Verificar lockout
if echo "$RESPONSE" | grep -q "Too many failed attempts"; then
    RETRY_AFTER=$(echo "$RESPONSE" | grep -oP '"retry_after":\K[0-9]+' || echo "300")
    echo ""
    echo "⏳ Lockout ativo! Aguarde ${RETRY_AFTER}s ($((RETRY_AFTER / 60)) minutos)"
    echo ""
    echo "Opções:"
    echo "1. Aguardar ${RETRY_AFTER}s e rodar o script novamente"
    echo "2. Forçar reset (limpa o lockout):"
    echo "   cd $TENANT_DIR && docker compose down && docker compose up -d"
    echo ""
    read -p "Deseja fazer reset agora? [y/N]: " RESET_CHOICE
    if [[ "$RESET_CHOICE" =~ ^[Yy]$ ]]; then
        echo "🔄 Fazendo reset do container..."
        cd "$TENANT_DIR" && docker compose down > /dev/null 2>&1
        docker compose up -d > /dev/null 2>&1
        echo "⏳ Aguardando inicialização (15s)..."
        sleep 15
        # Continuar com novo código abaixo
    else
        exit 1
    fi
fi

# Se o pairing falhar por código inválido, tenta reiniciar e gerar novo código
if echo "$RESPONSE" | grep -q "Invalid pairing code"; then
    echo "⚠️  Código inválido (já foi usado). Gerando novo código..."
    echo ""
    
    OLD_CODE="$PAIRING_CODE"
    
    # Para e inicia novamente (down/up gera novo código com certeza)
    cd "$TENANT_DIR" && docker compose down > /dev/null 2>&1
    echo "⏳ Iniciando container e aguardando novo código (15s)..."
    docker compose up -d > /dev/null 2>&1
    sleep 15
    
    # Busca novo código (deve ser diferente)
    for i in {1..5}; do
        PAIRING_CODE=$(docker logs --tail 50 "$CONTAINER" 2>&1 | grep -A 3 "PAIRING REQUIRED" | grep -oE '[0-9]{6}' | tail -n1)
        
        # Verifica se é um código diferente
        if [ -n "$PAIRING_CODE" ] && [ "$PAIRING_CODE" != "$OLD_CODE" ]; then
            echo "✅ Código único encontrado: $PAIRING_CODE"
            break
        fi
        
        echo "⏳ Aguardando código diferente... tentativa $i/5 (atual: ${PAIRING_CODE:-nenhum})"
        sleep 3
    done
    
    if [ -z "$PAIRING_CODE" ] || [ "$PAIRING_CODE" = "$OLD_CODE" ]; then
        echo "❌ Não foi possível obter novo código único."
        echo "Código antigo: $OLD_CODE"
        echo "Código atual: $PAIRING_CODE"
        echo ""
        echo "Tente manualmente:"
        echo "1. cd $TENANT_DIR"
        echo "2. docker compose down && docker compose up -d"
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

echo "🔍 [DEBUG] Tentando extrair token da resposta..."
# Extrair token
TOKEN=$(echo "$RESPONSE" | grep -oP '"token":"\K[^"]+')
echo "🔍 [DEBUG] Token extraído: '$TOKEN'"

if [ -z "$TOKEN" ]; then
    echo "❌ Não foi possível extrair o token"
    echo "🔍 [DEBUG] Resposta completa:"
    echo "$RESPONSE"
    exit 1
fi

echo "🔑 Token obtido:"
echo "$TOKEN"
echo ""

echo "🔍 [DEBUG] Salvando token no .env: $ENV_FILE"
# Salvar token no .env
if grep -q "^ZEROCLAW_TOKEN=" "$ENV_FILE"; then
    echo "🔍 [DEBUG] Token já existe no .env, atualizando..."
    sed -i "s|^ZEROCLAW_TOKEN=.*|ZEROCLAW_TOKEN=$TOKEN|" "$ENV_FILE"
else
    echo "🔍 [DEBUG] Adicionando novo token ao .env..."
    echo "ZEROCLAW_TOKEN=$TOKEN" >> "$ENV_FILE"
fi

echo "💾 Token salvo em $ENV_FILE"
echo ""

# Reiniciar container
echo "🔄 Reiniciando container..."
echo "🔍 [DEBUG] Executando: cd $TENANT_DIR && docker compose restart"
cd "$TENANT_DIR" && docker compose restart
echo ""

# Testar webhook
echo "🚀 Enviando mensagem de teste..."
echo "🔍 [DEBUG] URL: http://localhost:$PORT/webhook"
echo "🔍 [DEBUG] Token: $TOKEN"

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
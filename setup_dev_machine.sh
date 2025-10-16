#!/bin/bash

# ---
# Script para configurar ambiente, com controle de versão. (VERSÃO 5)
# - Verifica a versão instalada antes de executar.
# - Limpa versões antigas antes de baixar as novas.
# - Executa o script de instalação do Zabbix no final.
# ---

# Interrompe o script se qualquer comando falhar
set -e

# --- CONFIGURAÇÃO ---
# Altere esta variável para forçar uma atualização na próxima vez que o script rodar.
CURRENT_VERSION="1.0.0"
VERSION_FILE="$HOME/.box_installer_version"
# --------------------

echo "🚀 Iniciando o instalador do Box (versão do script: $CURRENT_VERSION)..."

# 1. VERIFICAÇÃO DE VERSÃO
# -----------------------------------------------------------------------------
INSTALLED_VERSION=""
if [ -f "$VERSION_FILE" ]; then
    INSTALLED_VERSION=$(cat "$VERSION_FILE")
fi

if [ "$INSTALLED_VERSION" == "$CURRENT_VERSION" ]; then
    echo "✅ Você já possui a versão mais recente ($CURRENT_VERSION). Nenhuma ação necessária."
    exit 0 # Encerra o script com sucesso
fi

if [ -n "$INSTALLED_VERSION" ]; then
    echo "ℹ️  Versão desatualizada encontrada ($INSTALLED_VERSION). Atualizando para a $CURRENT_VERSION..."
else
    echo "ℹ️  Nenhuma versão encontrada. Iniciando nova instalação..."
fi

# 2. INSTALAÇÃO DE DEPENDÊNCIAS
# -----------------------------------------------------------------------------
echo "📦 Verificando e instalando dependências..."
sudo apt-get update -y > /dev/null
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin python3 python3-pip nodejs git

# 3. LIMPEZA DA VERSÃO ANTIGA
# -----------------------------------------------------------------------------
# Detecta o diretório de destino (Documentos ou Documents)
if [ -d "$HOME/Documentos" ]; then
    DEST_DIR="$HOME/Documentos"
else
    DEST_DIR="$HOME/Documents"
fi
mkdir -p "$DEST_DIR"

ZABBIX_PROJECT_PATH="$DEST_DIR/instalador-client-zabbix"
BOX_SCRIPT_PROJECT_PATH="$DEST_DIR/box-script"

echo "🧹 Limpando instalações antigas (se existirem)..."
if [ -d "$ZABBIX_PROJECT_PATH" ]; then
    rm -rf "$ZABBIX_PROJECT_PATH"
    echo "   -> Removido: $ZABBIX_PROJECT_PATH"
fi
if [ -d "$BOX_SCRIPT_PROJECT_PATH" ]; then
    rm -rf "$BOX_SCRIPT_PROJECT_PATH"
    echo "   -> Removido: $BOX_SCRIPT_PROJECT_PATH"
fi

# 4. DOWNLOAD E CONFIGURAÇÃO
# -----------------------------------------------------------------------------
echo "📂 Projetos serão baixados em '$DEST_DIR'."
cd "$DEST_DIR"

echo "⏬ Baixando 'instalador-client-zabbix'..."
git clone https://github.com/InnovatioLab/instalador-client-zabbix.git

echo "⏬ Baixando 'box-script'..."
git clone https://github.com/InnovatioLab/box-script.git

ZABBIX_SCRIPT_PATH="$ZABBIX_PROJECT_PATH/zabbix_manager_ubuntu.sh"

echo "🔒 Concedendo permissão de execução para o script do Zabbix..."
if [ -f "$ZABBIX_SCRIPT_PATH" ]; then
    chmod +x "$ZABBIX_SCRIPT_PATH"
    echo "▶️  Executando o script do Zabbix Manager..."
    sudo "$ZABBIX_SCRIPT_PATH"
else
    echo "❌ ERRO: O script do Zabbix não foi encontrado em '$ZABBIX_SCRIPT_PATH'."
    exit 1
fi

# 5. SALVAR A NOVA VERSÃO
# -----------------------------------------------------------------------------
echo "💾 Salvando a versão da instalação atual ($CURRENT_VERSION)..."
echo "$CURRENT_VERSION" > "$VERSION_FILE"

echo "🎉🎉🎉 Instalação/Atualização para a versão $CURRENT_VERSION concluída com sucesso! 🎉🎉🎉"

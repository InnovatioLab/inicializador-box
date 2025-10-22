#!/bin/bash

# ---
# Script para configurar ambiente, com controle de versão. (VERSÃO 7)
# - Corrigido erro de sintaxe (falta de '\') no comando de instalação.
# ---

# Interrompe o script se qualquer comando falhar
set -e

# --- CONFIGURAÇÃO ---
CURRENT_VERSION="1.0.2" # Incrementado para garantir que a atualização rode
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
    exit 0
fi

if [ -n "$INSTALLED_VERSION" ]; then
    echo "ℹ️  Versão desatualizada encontrada ($INSTALLED_VERSION). Atualizando para a $CURRENT_VERSION..."
else
    echo "ℹ️  Nenhuma versão encontrada. Iniciando nova instalação..."
fi

# 2. INSTALAÇÃO DE DEPENDÊNCIAS (COM SINTAXE CORRIGIDA)
# -----------------------------------------------------------------------------
echo "📦 Verificando e instalando todas as dependências..."
sudo apt-get update -y > /dev/null

# Docker e Docker Compose plugin
echo "Instalando Docker e Docker Compose plugin..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "✅ Dependências instaladas com sucesso!"

# 3. LIMPEZA E DOWNLOAD
# -----------------------------------------------------------------------------
# Detecta o diretório de destino
if [ -d "$HOME/Documentos" ]; then
    DEST_DIR="$HOME/Documentos"
else
    DEST_DIR="$HOME/Documents"
fi
mkdir -p "$DEST_DIR"

echo "🧹 Limpando instalações antigas para garantir uma instalação limpa..."
rm -rf "$DEST_DIR/instalador-client-zabbix"
rm -rf "$DEST_DIR/box-script"

echo "📂 Projetos serão baixados em '$DEST_DIR'."
cd "$DEST_DIR"

echo "⏬ Baixando 'instalador-client-zabbix'..."
git clone https://github.com/InnovatioLab/instalador-client-zabbix.git

echo "⏬ Baixando 'box-script' e criando .env..."
git clone https://github.com/InnovatioLab/box-script.git
echo "API_KEY=Qw8!pZr2@tLx7sVb6kJm9^eHf4&uYc1" > "$DEST_DIR/box-script/.env"
echo "✅ Arquivo .env criado em 'box-script'."

# 4. EXECUÇÃO DO INSTALADOR ZABBIX
# -----------------------------------------------------------------------------
ZABBIX_SCRIPT_PATH="$DEST_DIR/instalador-client-zabbix/zabbix_manager_ubuntu.sh"

echo "🔒 Configurando e executando o script do Zabbix..."
if [ -f "$ZABBIX_SCRIPT_PATH" ]; then
    chmod +x "$ZABBIX_SCRIPT_PATH"
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

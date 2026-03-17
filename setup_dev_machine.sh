#!/bin/bash

# ---
# Script para configurar ambiente - VERSÃO 7.2 (Compatível Ubuntu 22/24)
# ---

set -e

# --- CONFIGURAÇÃO ---
CURRENT_VERSION="1.0.2"
TARGET_USER="telas"
USER_HOME="/home/$TARGET_USER"
VERSION_FILE="$USER_HOME/.box_installer_version"

# Verifica root
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, rode como root (ex: sudo ./setup_dev_machine.sh)"
  exit 1
fi

echo "🚀 Iniciando o instalador do Box (Versão: $CURRENT_VERSION)..."

# 1. VERIFICAÇÃO DE VERSÃO
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

# 2. INSTALAÇÃO DE DEPENDÊNCIAS
echo "📦 Instalando dependências..."

apt-get update -y

apt-get install -y \
docker.io \
docker-compose \
git \
wget \
curl

# Garantindo que o docker esteja ativo
systemctl enable docker
systemctl start docker

# 3. TEAMVIEWER
echo "📦 Instalando TeamViewer..."

wget https://download.teamviewer.com/download/linux/teamviewer_amd64.deb -P /tmp

apt-get install -y /tmp/teamviewer_amd64.deb || apt-get -f install -y

rm -f /tmp/teamviewer_amd64.deb

# 4. DOWNLOAD E PROJETOS
DEST_DIR="$USER_HOME/Documentos"

mkdir -p "$DEST_DIR"

echo "🧹 Limpando e baixando projetos em $DEST_DIR..."

rm -rf \
"$DEST_DIR/instalador-client-zabbix" \
"$DEST_DIR/box-script"

cd "$DEST_DIR"

git clone https://github.com/InnovatioLab/instalador-client-zabbix.git
git clone https://github.com/InnovatioLab/box-script.git

# Criando .env
echo "API_KEY=Qw8!pZr2@tLx7sVb6kJm9^eHf4&uYc1" > "$DEST_DIR/box-script/.env"

# 5. EXECUÇÃO DO ZABBIX
ZABBIX_SCRIPT_PATH="$DEST_DIR/instalador-client-zabbix/zabbix_manager_ubuntu.sh"

if [ -f "$ZABBIX_SCRIPT_PATH" ]; then
    chmod +x "$ZABBIX_SCRIPT_PATH"
    bash "$ZABBIX_SCRIPT_PATH"
else
    echo "⚠️ Aviso: Script Zabbix não encontrado."
fi

# 6. AJUSTE DE PERMISSÕES
echo "🔐 Ajustando permissões..."

chown -R $TARGET_USER:$TARGET_USER "$USER_HOME"

# 7. SALVAR VERSÃO
echo "$CURRENT_VERSION" > "$VERSION_FILE"
chown $TARGET_USER:$TARGET_USER "$VERSION_FILE"

echo "🎉 Instalação concluída com sucesso!"

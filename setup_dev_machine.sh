#!/bin/bash

# ---
# Script para configurar ambiente - VERSÃO 7.1 (Otimizada para Autoinstall)
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
echo "📦 Instalando dependências e TeamViewer..."
apt-get update -y
# Instalando docker.io (mais estável para scripts simples de autoinstall)
apt-get install -y docker.io docker-compose docker-compose-plugin

# TeamViewer
wget https://download.teamviewer.com/download/linux/teamviewer_amd64.deb -P /tmp
apt-get install -y /tmp/teamviewer_amd64.deb
rm /tmp/teamviewer_amd64.deb

# 3. DOWNLOAD E PROJETOS
# Garantindo que a pasta Documentos exista para o usuário correto
DEST_DIR="$USER_HOME/Documentos"
mkdir -p "$DEST_DIR"

echo "🧹 Limpando e baixando projetos em $DEST_DIR..."
rm -rf "$DEST_DIR/instalador-client-zabbix" "$DEST_DIR/box-script"

cd "$DEST_DIR"
git clone https://github.com/InnovatioLab/instalador-client-zabbix.git
git clone https://github.com/InnovatioLab/box-script.git

# Criando .env
echo "API_KEY=Qw8!pZr2@tLx7sVb6kJm9^eHf4&uYc1" > "$DEST_DIR/box-script/.env"

# 4. EXECUÇÃO DO ZABBIX
ZABBIX_SCRIPT_PATH="$DEST_DIR/instalador-client-zabbix/zabbix_manager_ubuntu.sh"
if [ -f "$ZABBIX_SCRIPT_PATH" ]; then
    chmod +x "$ZABBIX_SCRIPT_PATH"
    bash "$ZABBIX_SCRIPT_PATH" # Executa direto como root
else
    echo "⚠️ Aviso: Script Zabbix não encontrado."
fi

# 5. AJUSTE DE PERMISSÕES (Crucial!)
# Como o script rodou como root, os arquivos pertencem ao root. 
# Precisamos devolver ao usuário 'telas'.
chown -R $TARGET_USER:$TARGET_USER "$USER_HOME"

# 6. SALVAR VERSÃO
echo "$CURRENT_VERSION" > "$VERSION_FILE"
chown $TARGET_USER:$TARGET_USER "$VERSION_FILE"

echo "🎉 Instalação concluída com sucesso!"

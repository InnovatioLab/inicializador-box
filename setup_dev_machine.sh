#!/bin/bash

# ---
# Script para configurar ambiente de desenvolvimento e baixar projetos. (VERSÃO 4 - FINAL)
# 1. Instala Docker (versão oficial), Docker Compose plugin, Python, Node.js (LTS), npm, Git e dependências do Electron.
# 2. Detecta a pasta 'Documentos' ou 'Documents'.
# 3. Clona os repositórios 'instalador-client-zabbix' e 'box-script' para dentro da pasta de documentos.
# 4. Cria/atualiza o .env do box-script.
# 5. Concede permissão de execução ao script do Zabbix.
# ---

set -e

echo "🚀 Iniciando a configuração da máquina (v4)..."

# 1. Instalação de dependências
# -----------------------------------------------------------------------------
echo "📦 Verificando e instalando dependências..."

sudo apt-get update -y > /dev/null

# Docker e Docker Compose plugin
echo "Instalando Docker e Docker Compose plugin..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Python, Git
echo "Instalando Python e Git..."
sudo apt-get install -y python3 python3-pip git

# Node.js (LTS) e npm
echo "Instalando Node.js (LTS) e npm..."
sudo apt-get install -y curl
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Dependências do Electron (as do Dockerfile)
echo "Instalando dependências do Electron..."
sudo apt-get install -y \
    libx11-xcb1 \
    libxcb-dri3-0 \
    libxtst6 \
    libnss3 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libxss1 \
    libasound2 \
    libdrm2 \
    libgbm1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxkbcommon0 \
    libx11-6 \
    libxcb1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libgdk-pixbuf2.0-0 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libcups2 \
    libatk1.0-0 \
    libcurl4 \
    libgl1-mesa-glx \
    libcanberra-gtk-module \
    x11-apps

echo "✅ Dependências instaladas com sucesso!"

# Adiciona o usuário atual ao grupo do docker para não precisar usar 'sudo'
if groups $USER | grep &>/dev/null '\bdocker\b'; then
    echo "👍 Usuário '$USER' já pertence ao grupo 'docker'."
else
    echo "🔧 Adicionando o usuário '$USER' ao grupo 'docker'..."
    sudo usermod -aG docker $USER
    echo "⚠️ Lembre-se de fazer logout e login novamente para usar o Docker sem 'sudo'."
fi

# 2. Detectar e definir o diretório de destino
# -----------------------------------------------------------------------------
if [ -d "$HOME/Documentos" ]; then
    DEST_DIR="$HOME/Documentos"
elif [ -d "$HOME/Documents" ]; then
    DEST_DIR="$HOME/Documents"
else
    DEST_DIR="$HOME/Documents"
fi

echo "📂 Projetos serão baixados em '$DEST_DIR'."
mkdir -p "$DEST_DIR"

# 3. Download dos repositórios
# -----------------------------------------------------------------------------
cd "$DEST_DIR"

# Repositório 1: Zabbix Client
echo "⏬ Verificando/Baixando 'instalador-client-zabbix'..."
if [ ! -d "instalador-client-zabbix" ]; then
    git clone https://github.com/InnovatioLab/instalador-client-zabbix.git
else
    echo "👍 Repositório 'instalador-client-zabbix' já existe."
fi

# Repositório 2: Box Script
echo "⏬ Verificando/Baixando 'box-script'..."
if [ ! -d "box-script" ]; then
    git clone https://github.com/InnovatioLab/box-script.git
    echo "API_KEY=Qw8!pZr2@tLx7sVb6kJm9^eHf4&uYc1" > "$DEST_DIR/box-script/.env"
    echo "✅ Arquivo .env criado em 'box-script' com API_KEY."
else
    echo "👍 Repositório 'box-script' já existe."
    echo "API_KEY=Qw8!pZr2@tLx7sVb6kJm9^eHf4&uYc1" > "$DEST_DIR/box-script/.env"
    echo "✅ Arquivo .env atualizado em 'box-script' com API_KEY."
fi

# 4. Instalar dependências Node.js do box-script
echo "📦 Instalando dependências Node.js do box-script..."
cd "$DEST_DIR/box-script"
npm install

# 5. Conceder permissão de execução ao script do Zabbix
ZABBIX_SCRIPT_PATH="$DEST_DIR/instalador-client-zabbix/install_zabbix_agent_client.sh"
echo "🔒 Concedendo permissão de execução para o script do Zabbix..."
if [ -f "$ZABBIX_SCRIPT_PATH" ]; then
    chmod +x "$ZABBIX_SCRIPT_PATH"
    echo "✅ Permissão concedida para '$ZABBIX_SCRIPT_PATH'."
else
    echo "⚠️ Atenção: O script do Zabbix não foi encontrado. Verifique o repositório ou o nome do arquivo."
fi

echo "🎉🎉🎉 Configuração concluída com sucesso! 🎉🎉🎉"
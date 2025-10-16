#!/bin/bash

# ---
# Script para configurar ambiente de desenvolvimento e baixar projetos. (VERSÃO 3 - FINAL)
# 1. Instala Docker (versão oficial), Python, Node.js e Git.
# 2. Detecta a pasta 'Documentos' ou 'Documents'.
# 3. Clona os repositórios 'instalador-client-zabbix' e 'box-script' para dentro da pasta de documentos.
# 4. Concede permissão de execução ao script do Zabbix.
# ---

# Interrompe o script se qualquer comando falhar
set -e

echo "🚀 Iniciando a configuração da máquina (v3)..."

# 1. Instalação de dependências
# -----------------------------------------------------------------------------
echo "📦 Verificando e instalando dependências..."
sudo apt-get update -y > /dev/null
echo "Instalando Docker, Python, Node.js e Git..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin python3 python3-pip nodejs git

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
# Verifica se a pasta "Documentos" (pt-BR) existe, senão usa "Documents" (en)
if [ -d "$HOME/Documentos" ]; then
    DEST_DIR="$HOME/Documentos"
elif [ -d "$HOME/Documents" ]; then
    DEST_DIR="$HOME/Documents"
else
    # Se nenhuma existir, cria "Documents" por padrão
    DEST_DIR="$HOME/Documents"
fi

echo "📂 Projetos serão baixados em '$DEST_DIR'."
# Cria o diretório de destino se ele não existir
mkdir -p "$DEST_DIR"


# 3. Download dos repositórios
# -----------------------------------------------------------------------------
# Navega até o diretório de destino
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
else
    echo "👍 Repositório 'box-script' já existe."
fi

# 4. Conceder permissão de execução ao script do Zabbix
# -----------------------------------------------------------------------------
ZABBIX_SCRIPT_PATH="$DEST_DIR/instalador-client-zabbix/install_zabbix_agent_client.sh"

echo "🔒 Concedendo permissão de execução para o script do Zabbix..."

if [ -f "$ZABBIX_SCRIPT_PATH" ]; then
    chmod +x "$ZABBIX_SCRIPT_PATH"
    echo "✅ Permissão concedida para '$ZABBIX_SCRIPT_PATH'."
else
    echo "⚠️ Atenção: O script do Zabbix não foi encontrado. Verifique o repositório ou o nome do arquivo."
fi

echo "🎉🎉🎉 Configuração concluída com sucesso! 🎉🎉🎉"
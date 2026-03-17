import yaml
import sys

def validate_autoinstall(file_path):
    try:
        with open(file_path, 'r') as f:
            data = yaml.safe_load(f)
        
        # Verificações básicas de estrutura autoinstall
        if 'autoinstall' not in data:
            print("❌ Erro: Chave principal 'autoinstall' não encontrada.")
            return
        
        version = data['autoinstall'].get('version')
        if version != 1:
            print(f"⚠️ Aviso: Versão do autoinstall é {version}, o esperado é 1.")

        print("✅ Sucesso: A sintaxe YAML está correta e o arquivo foi lido sem erros.")
        
    except yaml.YAMLError as exc:
        print(f"❌ Erro de Sintaxe no YAML:\n{exc}")
    except FileNotFoundError:
        print(f"❌ Erro: Arquivo {file_path} não encontrado.")

if __name__ == "__main__":
    validate_autoinstall('autoinstall.yaml')
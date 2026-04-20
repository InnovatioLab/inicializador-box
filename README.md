# Inicializador Box

Provisionamento das boxes padronizado para Ubuntu 24.04.

## Fluxo

1. O `autoinstall.yaml` instala apenas a base do host.
2. Durante a instalação, o bootstrap é baixado do repositório `inicializador-box` via GitHub.
3. No primeiro boot, a unit `box-firstboot.service` chama `setup_dev_machine.sh`.
4. O bootstrap é dividido em:
   - `scripts/bootstrap_host.sh`
   - `scripts/install_observability.sh`
   - `scripts/enroll_box.sh`
   - `scripts/install_player.sh`
5. O player sobe por `systemd` via `box-player.service`.

## Configuração

Se o primeiro boot parar por falta de segredos, edite:

```bash
sudo nano /etc/box/box.env
```

Preencha no mínimo:

- `GITHUB_TOKEN`
- `BOX_API_KEY`

Opcionalmente:

- `TAILSCALE_AUTH_KEY`
- `ZABBIX_HOST`
- `BOX_ID`

Depois finalize com:

```bash
sudo /root/inicializador-box/setup_dev_machine.sh
```

## Repositório privado

O clone usa `Authorization: Bearer` apenas durante a operação do Git, sem persistir o token na URL remota do `.git/config`.

## Boot automático

- `box-display-access.service`: prepara acesso ao X11 após o ambiente gráfico.
- `box-player.service`: sobe o `docker compose` do `box-script-v2`.
- `restart: unless-stopped` continua no Compose, mas o boot do host fica sob responsabilidade do `systemd`.

## Queda de energia

Para a box religar sozinha após retorno de energia, habilite no hardware uma opção equivalente a:

- `Restore on AC Power Loss`
- `After Power Failure`
- `AC Back`

Essa parte continua dependente do modelo da placa/mini PC.

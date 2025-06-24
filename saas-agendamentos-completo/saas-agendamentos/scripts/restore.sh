#!/bin/bash

# Script de restore para o sistema SaaS de Agendamentos
# Autor: Sistema AgendaFácil
# Data: $(date +%Y-%m-%d)

set -e

# Configurações
BACKUP_DIR="/home/ubuntu/saas-agendamentos/backups"
DB_NAME="${DB_NAME:-saas_agendamentos}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres123}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Mostrar uso
show_usage() {
    echo "Uso: $0 [OPÇÕES] ARQUIVO_BACKUP"
    echo ""
    echo "Opções:"
    echo "  -h, --help              Mostrar esta ajuda"
    echo "  -l, --list              Listar backups disponíveis"
    echo "  -f, --force             Forçar restore sem confirmação"
    echo "  --db-only               Restaurar apenas o banco de dados"
    echo "  --uploads-only          Restaurar apenas os uploads"
    echo "  --configs-only          Restaurar apenas as configurações"
    echo ""
    echo "Exemplos:"
    echo "  $0 db_backup_20240101_120000.sql.gz"
    echo "  $0 --list"
    echo "  $0 --db-only db_backup_20240101_120000.sql.gz"
}

# Listar backups disponíveis
list_backups() {
    log "Backups disponíveis em $BACKUP_DIR:"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ]; then
        error "Diretório de backup não encontrado: $BACKUP_DIR"
        exit 1
    fi
    
    # Listar backups de banco
    echo -e "${BLUE}Backups de Banco de Dados:${NC}"
    find "$BACKUP_DIR" -name "db_backup_*.sql.gz" -type f -exec ls -lh {} \; | \
        awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
    
    echo ""
    
    # Listar backups de uploads
    echo -e "${BLUE}Backups de Uploads:${NC}"
    find "$BACKUP_DIR" -name "uploads_backup_*.tar.gz" -type f -exec ls -lh {} \; | \
        awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
    
    echo ""
    
    # Listar backups de configurações
    echo -e "${BLUE}Backups de Configurações:${NC}"
    find "$BACKUP_DIR" -name "configs_backup_*.tar.gz" -type f -exec ls -lh {} \; | \
        awk '{print "  " $9 " (" $5 ", " $6 " " $7 " " $8 ")"}'
}

# Verificar se o PostgreSQL está disponível
check_postgres() {
    log "Verificando conexão com PostgreSQL..."
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -c '\q' 2>/dev/null; then
        error "Não foi possível conectar ao PostgreSQL"
        exit 1
    fi
    log "Conexão com PostgreSQL OK"
}

# Confirmar ação
confirm_action() {
    local message="$1"
    
    if [ "$FORCE" = "true" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}$message${NC}"
    read -p "Tem certeza? (sim/não): " response
    
    case "$response" in
        [Ss][Ii][Mm]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            log "Operação cancelada pelo usuário"
            exit 0
            ;;
    esac
}

# Restaurar banco de dados
restore_database() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        error "Arquivo de backup não encontrado: $backup_file"
        exit 1
    fi
    
    log "Restaurando banco de dados de: $backup_file"
    
    # Confirmar ação
    confirm_action "ATENÇÃO: Esta operação irá SOBRESCREVER o banco de dados atual!"
    
    # Parar containers se estiverem rodando
    log "Parando containers..."
    cd /home/ubuntu/saas-agendamentos
    docker-compose down || true
    
    # Aguardar um pouco
    sleep 5
    
    # Subir apenas o PostgreSQL
    log "Iniciando PostgreSQL..."
    docker-compose up -d postgres
    
    # Aguardar PostgreSQL ficar pronto
    log "Aguardando PostgreSQL ficar pronto..."
    sleep 10
    
    # Verificar conexão
    check_postgres
    
    # Descomprimir se necessário
    local sql_file="$backup_file"
    if [[ "$backup_file" == *.gz ]]; then
        log "Descomprimindo backup..."
        sql_file="${backup_file%.gz}"
        gunzip -c "$backup_file" > "$sql_file"
    fi
    
    # Restaurar banco
    log "Executando restore do banco..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres < "$sql_file"
    
    if [ $? -eq 0 ]; then
        log "Banco de dados restaurado com sucesso"
        
        # Limpar arquivo temporário se foi descomprimido
        if [[ "$backup_file" == *.gz ]]; then
            rm -f "$sql_file"
        fi
    else
        error "Falha ao restaurar banco de dados"
        exit 1
    fi
    
    # Reiniciar todos os containers
    log "Reiniciando todos os containers..."
    docker-compose up -d
}

# Restaurar uploads
restore_uploads() {
    local backup_file="$1"
    local uploads_dir="/home/ubuntu/saas-agendamentos/backend/uploads"
    
    if [ ! -f "$backup_file" ]; then
        error "Arquivo de backup não encontrado: $backup_file"
        exit 1
    fi
    
    log "Restaurando uploads de: $backup_file"
    
    # Confirmar ação
    confirm_action "ATENÇÃO: Esta operação irá SOBRESCREVER os uploads atuais!"
    
    # Criar backup dos uploads atuais
    if [ -d "$uploads_dir" ]; then
        local current_backup="${uploads_dir}_backup_$(date +%Y%m%d_%H%M%S)"
        log "Fazendo backup dos uploads atuais para: $current_backup"
        mv "$uploads_dir" "$current_backup"
    fi
    
    # Restaurar uploads
    log "Extraindo uploads..."
    mkdir -p "$(dirname "$uploads_dir")"
    tar -xzf "$backup_file" -C "$(dirname "$uploads_dir")"
    
    if [ $? -eq 0 ]; then
        log "Uploads restaurados com sucesso"
        
        # Ajustar permissões
        chown -R 1000:1000 "$uploads_dir" 2>/dev/null || true
        chmod -R 755 "$uploads_dir" 2>/dev/null || true
    else
        error "Falha ao restaurar uploads"
        exit 1
    fi
}

# Restaurar configurações
restore_configs() {
    local backup_file="$1"
    local project_dir="/home/ubuntu/saas-agendamentos"
    
    if [ ! -f "$backup_file" ]; then
        error "Arquivo de backup não encontrado: $backup_file"
        exit 1
    fi
    
    log "Restaurando configurações de: $backup_file"
    
    # Confirmar ação
    confirm_action "ATENÇÃO: Esta operação irá SOBRESCREVER as configurações atuais!"
    
    # Parar containers
    log "Parando containers..."
    cd "$project_dir"
    docker-compose down || true
    
    # Restaurar configurações
    log "Extraindo configurações..."
    tar -xzf "$backup_file" -C "$project_dir"
    
    if [ $? -eq 0 ]; then
        log "Configurações restauradas com sucesso"
        
        # Reiniciar containers
        log "Reiniciando containers..."
        docker-compose up -d
    else
        error "Falha ao restaurar configurações"
        exit 1
    fi
}

# Função principal
main() {
    local backup_file=""
    local db_only=false
    local uploads_only=false
    local configs_only=false
    
    # Parse argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                list_backups
                exit 0
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --db-only)
                db_only=true
                shift
                ;;
            --uploads-only)
                uploads_only=true
                shift
                ;;
            --configs-only)
                configs_only=true
                shift
                ;;
            -*)
                error "Opção desconhecida: $1"
                show_usage
                exit 1
                ;;
            *)
                backup_file="$1"
                shift
                ;;
        esac
    done
    
    # Verificar se arquivo foi especificado
    if [ -z "$backup_file" ]; then
        error "Arquivo de backup não especificado"
        show_usage
        exit 1
    fi
    
    # Verificar se arquivo existe (adicionar caminho completo se necessário)
    if [ ! -f "$backup_file" ] && [ -f "$BACKUP_DIR/$backup_file" ]; then
        backup_file="$BACKUP_DIR/$backup_file"
    fi
    
    if [ ! -f "$backup_file" ]; then
        error "Arquivo de backup não encontrado: $backup_file"
        exit 1
    fi
    
    log "=== Iniciando restore do sistema SaaS Agendamentos ==="
    log "Arquivo: $backup_file"
    
    # Executar restore baseado no tipo
    if [ "$db_only" = true ]; then
        restore_database "$backup_file"
    elif [ "$uploads_only" = true ]; then
        restore_uploads "$backup_file"
    elif [ "$configs_only" = true ]; then
        restore_configs "$backup_file"
    else
        # Detectar tipo do arquivo automaticamente
        if [[ "$backup_file" == *"db_backup"* ]]; then
            restore_database "$backup_file"
        elif [[ "$backup_file" == *"uploads_backup"* ]]; then
            restore_uploads "$backup_file"
        elif [[ "$backup_file" == *"configs_backup"* ]]; then
            restore_configs "$backup_file"
        else
            error "Não foi possível detectar o tipo do backup. Use --db-only, --uploads-only ou --configs-only"
            exit 1
        fi
    fi
    
    log "=== Restore concluído com sucesso ==="
}

# Verificar se está sendo executado como script
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi


#!/bin/bash

# Script de backup automático para o sistema SaaS de Agendamentos
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
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Verificar se o PostgreSQL está disponível
check_postgres() {
    log "Verificando conexão com PostgreSQL..."
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
        error "Não foi possível conectar ao PostgreSQL"
        exit 1
    fi
    log "Conexão com PostgreSQL OK"
}

# Criar diretório de backup se não existir
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        log "Criando diretório de backup: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
}

# Fazer backup do banco de dados
backup_database() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/db_backup_${timestamp}.sql"
    local backup_file_gz="${backup_file}.gz"
    
    log "Iniciando backup do banco de dados..."
    log "Arquivo: $backup_file_gz"
    
    # Fazer dump do banco
    PGPASSWORD="$DB_PASSWORD" pg_dump \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --verbose \
        --clean \
        --if-exists \
        --create \
        --format=plain \
        > "$backup_file"
    
    if [ $? -eq 0 ]; then
        log "Dump do banco criado com sucesso"
        
        # Comprimir o arquivo
        gzip "$backup_file"
        
        if [ $? -eq 0 ]; then
            log "Backup comprimido: $backup_file_gz"
            log "Tamanho: $(du -h "$backup_file_gz" | cut -f1)"
        else
            error "Falha ao comprimir o backup"
            exit 1
        fi
    else
        error "Falha ao criar dump do banco"
        exit 1
    fi
}

# Backup dos uploads
backup_uploads() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local uploads_dir="/home/ubuntu/saas-agendamentos/backend/uploads"
    local backup_file="$BACKUP_DIR/uploads_backup_${timestamp}.tar.gz"
    
    if [ -d "$uploads_dir" ] && [ "$(ls -A "$uploads_dir" 2>/dev/null)" ]; then
        log "Fazendo backup dos uploads..."
        
        tar -czf "$backup_file" -C "$(dirname "$uploads_dir")" "$(basename "$uploads_dir")"
        
        if [ $? -eq 0 ]; then
            log "Backup dos uploads criado: $backup_file"
            log "Tamanho: $(du -h "$backup_file" | cut -f1)"
        else
            error "Falha ao criar backup dos uploads"
        fi
    else
        warning "Diretório de uploads vazio ou não encontrado"
    fi
}

# Backup das configurações
backup_configs() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local config_file="$BACKUP_DIR/configs_backup_${timestamp}.tar.gz"
    local project_dir="/home/ubuntu/saas-agendamentos"
    
    log "Fazendo backup das configurações..."
    
    tar -czf "$config_file" \
        -C "$project_dir" \
        --exclude="node_modules" \
        --exclude="venv" \
        --exclude="dist" \
        --exclude="build" \
        --exclude="*.log" \
        --exclude="backups" \
        docker-compose.yml \
        .env.example \
        nginx/ \
        scripts/ \
        README.md
    
    if [ $? -eq 0 ]; then
        log "Backup das configurações criado: $config_file"
        log "Tamanho: $(du -h "$config_file" | cut -f1)"
    else
        error "Falha ao criar backup das configurações"
    fi
}

# Limpar backups antigos
cleanup_old_backups() {
    log "Limpando backups antigos (mais de $RETENTION_DAYS dias)..."
    
    local deleted_count=0
    
    # Encontrar e deletar arquivos antigos
    while IFS= read -r -d '' file; do
        rm "$file"
        deleted_count=$((deleted_count + 1))
        log "Removido: $(basename "$file")"
    done < <(find "$BACKUP_DIR" -name "*.sql.gz" -o -name "*.tar.gz" -type f -mtime +$RETENTION_DAYS -print0)
    
    if [ $deleted_count -gt 0 ]; then
        log "Removidos $deleted_count backups antigos"
    else
        log "Nenhum backup antigo para remover"
    fi
}

# Upload para S3 (opcional)
upload_to_s3() {
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ] && [ -n "$BACKUP_S3_BUCKET" ]; then
        log "Enviando backups para S3..."
        
        # Verificar se aws cli está instalado
        if command -v aws >/dev/null 2>&1; then
            local timestamp=$(date +%Y%m%d_%H%M%S)
            
            # Upload dos arquivos mais recentes
            for file in "$BACKUP_DIR"/*_${timestamp:0:8}_*.{sql.gz,tar.gz}; do
                if [ -f "$file" ]; then
                    aws s3 cp "$file" "s3://$BACKUP_S3_BUCKET/$(basename "$file")"
                    if [ $? -eq 0 ]; then
                        log "Enviado para S3: $(basename "$file")"
                    else
                        error "Falha ao enviar para S3: $(basename "$file")"
                    fi
                fi
            done
        else
            warning "AWS CLI não encontrado, pulando upload para S3"
        fi
    fi
}

# Função principal
main() {
    log "=== Iniciando backup do sistema SaaS Agendamentos ==="
    
    create_backup_dir
    check_postgres
    backup_database
    backup_uploads
    backup_configs
    cleanup_old_backups
    upload_to_s3
    
    log "=== Backup concluído com sucesso ==="
    
    # Mostrar estatísticas
    local total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    local file_count=$(find "$BACKUP_DIR" -type f | wc -l)
    
    log "Estatísticas:"
    log "  - Total de arquivos: $file_count"
    log "  - Tamanho total: $total_size"
    log "  - Localização: $BACKUP_DIR"
}

# Verificar se está sendo executado como script
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi


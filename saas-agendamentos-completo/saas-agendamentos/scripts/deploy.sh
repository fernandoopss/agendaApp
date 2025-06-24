#!/bin/bash

# Script de deploy para o sistema SaaS de Agendamentos
# Autor: Sistema AgendaFácil
# Data: $(date +%Y-%m-%d)

set -e

# Configurações
PROJECT_DIR="/home/ubuntu/saas-agendamentos"
DOMAIN="${DOMAIN:-localhost}"
SSL_EMAIL="${SSL_EMAIL:-admin@localhost}"

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
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Opções:"
    echo "  -h, --help              Mostrar esta ajuda"
    echo "  -d, --domain DOMAIN     Definir domínio (padrão: localhost)"
    echo "  -e, --email EMAIL       Email para SSL (padrão: admin@localhost)"
    echo "  --dev                   Deploy em modo desenvolvimento"
    echo "  --prod                  Deploy em modo produção"
    echo "  --ssl                   Configurar SSL com Let's Encrypt"
    echo "  --no-ssl                Pular configuração SSL"
    echo "  --update                Atualizar containers existentes"
    echo ""
    echo "Exemplos:"
    echo "  $0 --domain meusite.com --email admin@meusite.com --ssl"
    echo "  $0 --dev"
    echo "  $0 --update"
}

# Verificar se está rodando como root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

# Verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    local missing_deps=()
    
    # Verificar Docker
    if ! command -v docker >/dev/null 2>&1; then
        missing_deps+=("docker.io")
    fi
    
    # Verificar Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi
    
    # Verificar NGINX
    if ! command -v nginx >/dev/null 2>&1; then
        missing_deps+=("nginx")
    fi
    
    # Verificar UFW
    if ! command -v ufw >/dev/null 2>&1; then
        missing_deps+=("ufw")
    fi
    
    # Verificar Certbot (se SSL for necessário)
    if [ "$SETUP_SSL" = "true" ] && ! command -v certbot >/dev/null 2>&1; then
        missing_deps+=("certbot" "python3-certbot-nginx")
    fi
    
    # Instalar dependências faltantes
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "Instalando dependências: ${missing_deps[*]}"
        apt update
        apt install -y "${missing_deps[@]}"
    else
        log "Todas as dependências estão instaladas"
    fi
}

# Configurar firewall
setup_firewall() {
    log "Configurando firewall..."
    
    # Resetar UFW
    ufw --force reset
    
    # Configurações básicas
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH
    ufw allow OpenSSH
    
    # Permitir HTTP e HTTPS
    ufw allow 'Nginx Full'
    
    # Permitir portas específicas para desenvolvimento
    if [ "$MODE" = "dev" ]; then
        ufw allow 3000  # Frontend dev
        ufw allow 5000  # Backend dev
        ufw allow 5432  # PostgreSQL
        ufw allow 6379  # Redis
    fi
    
    # Ativar firewall
    ufw --force enable
    
    log "Firewall configurado"
    ufw status
}

# Configurar NGINX
setup_nginx() {
    log "Configurando NGINX..."
    
    # Parar NGINX se estiver rodando
    systemctl stop nginx || true
    
    # Backup da configuração existente
    if [ -f /etc/nginx/sites-available/default ]; then
        cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Copiar configuração do projeto
    cp "$PROJECT_DIR/nginx/default.conf" /etc/nginx/sites-available/default
    
    # Substituir placeholder do domínio
    sed -i "s/DOMAIN/$DOMAIN/g" /etc/nginx/sites-available/default
    
    # Testar configuração
    nginx -t
    
    if [ $? -eq 0 ]; then
        log "Configuração do NGINX válida"
    else
        error "Configuração do NGINX inválida"
        exit 1
    fi
}

# Configurar SSL com Let's Encrypt
setup_ssl() {
    if [ "$SETUP_SSL" != "true" ] || [ "$DOMAIN" = "localhost" ]; then
        log "Pulando configuração SSL"
        return 0
    fi
    
    log "Configurando SSL com Let's Encrypt..."
    
    # Verificar se o domínio aponta para este servidor
    local server_ip=$(curl -s ifconfig.me)
    local domain_ip=$(dig +short "$DOMAIN" | tail -n1)
    
    if [ "$server_ip" != "$domain_ip" ]; then
        warning "O domínio $DOMAIN não aponta para este servidor ($server_ip vs $domain_ip)"
        warning "Certifique-se de que o DNS está configurado corretamente"
        read -p "Continuar mesmo assim? (s/N): " continue_ssl
        if [[ ! "$continue_ssl" =~ ^[Ss]$ ]]; then
            log "Configuração SSL cancelada"
            return 0
        fi
    fi
    
    # Iniciar NGINX temporariamente
    systemctl start nginx
    
    # Obter certificado
    certbot --nginx -d "$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive
    
    if [ $? -eq 0 ]; then
        log "SSL configurado com sucesso"
        
        # Configurar renovação automática
        (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
        
        log "Renovação automática configurada"
    else
        error "Falha ao configurar SSL"
        warning "Continuando sem SSL..."
    fi
}

# Configurar ambiente
setup_environment() {
    log "Configurando ambiente..."
    
    cd "$PROJECT_DIR"
    
    # Criar arquivo .env se não existir
    if [ ! -f .env ]; then
        log "Criando arquivo .env..."
        cp .env.example .env
        
        # Gerar secrets aleatórios
        local jwt_secret=$(openssl rand -hex 32)
        local jwt_refresh_secret=$(openssl rand -hex 32)
        
        # Atualizar .env
        sed -i "s/seu-jwt-secret-super-seguro/$jwt_secret/g" .env
        sed -i "s/seu-refresh-secret-super-seguro/$jwt_refresh_secret/g" .env
        sed -i "s/seudominio.com/$DOMAIN/g" .env
        sed -i "s/seu-email@seudominio.com/$SSL_EMAIL/g" .env
        
        # Definir modo
        if [ "$MODE" = "dev" ]; then
            sed -i "s/NODE_ENV=production/NODE_ENV=development/g" .env
        fi
        
        log "Arquivo .env criado. IMPORTANTE: Revise e ajuste as configurações!"
    else
        log "Arquivo .env já existe"
    fi
    
    # Criar diretórios necessários
    mkdir -p backend/uploads backend/logs backups
    
    # Ajustar permissões
    chown -R 1000:1000 backend/uploads backend/logs
    chmod -R 755 backend/uploads backend/logs
}

# Deploy dos containers
deploy_containers() {
    log "Fazendo deploy dos containers..."
    
    cd "$PROJECT_DIR"
    
    # Parar containers existentes
    docker-compose down || true
    
    # Limpar imagens antigas se for update
    if [ "$UPDATE_MODE" = "true" ]; then
        log "Removendo imagens antigas..."
        docker-compose down --rmi all || true
        docker system prune -f || true
    fi
    
    # Build e start dos containers
    log "Construindo e iniciando containers..."
    docker-compose up -d --build
    
    # Aguardar containers ficarem prontos
    log "Aguardando containers ficarem prontos..."
    sleep 30
    
    # Verificar status
    docker-compose ps
    
    # Verificar logs se houver problemas
    if ! docker-compose ps | grep -q "Up"; then
        error "Alguns containers não iniciaram corretamente"
        log "Logs dos containers:"
        docker-compose logs
        exit 1
    fi
    
    log "Containers iniciados com sucesso"
}

# Configurar cron jobs
setup_cron() {
    log "Configurando tarefas agendadas..."
    
    # Backup diário às 2h
    local backup_cron="0 2 * * * cd $PROJECT_DIR && ./scripts/backup.sh >> /var/log/saas-backup.log 2>&1"
    
    # Adicionar ao crontab se não existir
    if ! crontab -l 2>/dev/null | grep -q "backup.sh"; then
        (crontab -l 2>/dev/null; echo "$backup_cron") | crontab -
        log "Backup automático configurado (diário às 2h)"
    fi
    
    # Limpeza de logs semanalmente
    local cleanup_cron="0 3 * * 0 find $PROJECT_DIR/backend/logs -name '*.log' -mtime +7 -delete"
    
    if ! crontab -l 2>/dev/null | grep -q "find.*logs"; then
        (crontab -l 2>/dev/null; echo "$cleanup_cron") | crontab -
        log "Limpeza automática de logs configurada (semanal)"
    fi
}

# Verificar saúde do sistema
health_check() {
    log "Verificando saúde do sistema..."
    
    local errors=0
    
    # Verificar containers
    if ! docker-compose ps | grep -q "Up"; then
        error "Containers não estão rodando corretamente"
        errors=$((errors + 1))
    fi
    
    # Verificar NGINX
    if ! systemctl is-active --quiet nginx; then
        error "NGINX não está rodando"
        errors=$((errors + 1))
    fi
    
    # Verificar conectividade
    if ! curl -f http://localhost/health >/dev/null 2>&1; then
        error "Aplicação não está respondendo"
        errors=$((errors + 1))
    fi
    
    # Verificar SSL se configurado
    if [ "$SETUP_SSL" = "true" ] && [ "$DOMAIN" != "localhost" ]; then
        if ! curl -f https://"$DOMAIN"/health >/dev/null 2>&1; then
            warning "HTTPS não está funcionando corretamente"
        fi
    fi
    
    if [ $errors -eq 0 ]; then
        log "Sistema está funcionando corretamente!"
        return 0
    else
        error "Encontrados $errors problemas no sistema"
        return 1
    fi
}

# Mostrar informações finais
show_final_info() {
    log "=== Deploy concluído ==="
    echo ""
    info "Informações do sistema:"
    echo "  - Projeto: $PROJECT_DIR"
    echo "  - Domínio: $DOMAIN"
    echo "  - Modo: $MODE"
    
    if [ "$DOMAIN" = "localhost" ]; then
        echo "  - URL: http://localhost"
        echo "  - API: http://localhost/api"
    else
        if [ "$SETUP_SSL" = "true" ]; then
            echo "  - URL: https://$DOMAIN"
            echo "  - API: https://$DOMAIN/api"
        else
            echo "  - URL: http://$DOMAIN"
            echo "  - API: http://$DOMAIN/api"
        fi
    fi
    
    echo ""
    info "Comandos úteis:"
    echo "  - Ver logs: cd $PROJECT_DIR && docker-compose logs -f"
    echo "  - Parar sistema: cd $PROJECT_DIR && docker-compose down"
    echo "  - Reiniciar: cd $PROJECT_DIR && docker-compose restart"
    echo "  - Backup: cd $PROJECT_DIR && ./scripts/backup.sh"
    echo "  - Status: cd $PROJECT_DIR && docker-compose ps"
    
    echo ""
    warning "IMPORTANTE:"
    echo "  1. Revise o arquivo .env em $PROJECT_DIR/.env"
    echo "  2. Configure as variáveis de email e outros serviços"
    echo "  3. Faça backup regularmente"
    echo "  4. Monitore os logs regularmente"
}

# Função principal
main() {
    local MODE="prod"
    local SETUP_SSL="false"
    local UPDATE_MODE="false"
    
    # Parse argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -e|--email)
                SSL_EMAIL="$2"
                shift 2
                ;;
            --dev)
                MODE="dev"
                shift
                ;;
            --prod)
                MODE="prod"
                shift
                ;;
            --ssl)
                SETUP_SSL="true"
                shift
                ;;
            --no-ssl)
                SETUP_SSL="false"
                shift
                ;;
            --update)
                UPDATE_MODE="true"
                shift
                ;;
            -*)
                error "Opção desconhecida: $1"
                show_usage
                exit 1
                ;;
            *)
                error "Argumento inesperado: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Verificar se está no diretório correto
    if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
        error "Projeto não encontrado em $PROJECT_DIR"
        exit 1
    fi
    
    log "=== Iniciando deploy do sistema SaaS Agendamentos ==="
    log "Domínio: $DOMAIN"
    log "Modo: $MODE"
    log "SSL: $SETUP_SSL"
    
    # Executar deploy
    check_root
    check_dependencies
    setup_firewall
    setup_environment
    setup_nginx
    deploy_containers
    
    # Iniciar NGINX
    systemctl start nginx
    systemctl enable nginx
    
    # Configurar SSL se solicitado
    setup_ssl
    
    # Configurar cron jobs
    setup_cron
    
    # Verificar saúde
    sleep 10
    if health_check; then
        show_final_info
    else
        error "Deploy concluído com problemas. Verifique os logs."
        exit 1
    fi
}

# Verificar se está sendo executado como script
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi


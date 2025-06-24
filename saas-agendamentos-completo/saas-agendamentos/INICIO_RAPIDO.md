# 🚀 Início Rápido - Sistema SaaS de Agendamento Online

## ⚡ Deploy em 5 Minutos

### 1. Preparar Servidor
```bash
# Conectar ao servidor Ubuntu
ssh root@seu-servidor.com

# Baixar projeto
cd /home/ubuntu
git clone https://github.com/seu-usuario/saas-agendamentos.git
cd saas-agendamentos
```

### 2. Deploy Automático
```bash
# Deploy completo com SSL
sudo ./scripts/deploy.sh --domain seudominio.com --email admin@seudominio.com --ssl

# Ou deploy local para testes
sudo ./scripts/deploy.sh --dev
```

### 3. Acessar Sistema
- **URL**: https://seudominio.com
- **Admin**: admin@demo.com / 123456
- **Prestador**: prestador@demo.com / 123456
- **Cliente**: cliente@demo.com / 123456

## 📁 Estrutura do Projeto

```
saas-agendamentos/
├── 📂 backend/          # API Flask
├── 📂 frontend/         # React App
├── 📂 nginx/           # Configurações NGINX
├── 📂 scripts/         # Scripts de deploy/backup
├── 📄 docker-compose.yml
├── 📄 .env.example
└── 📚 Documentação/
    ├── README.pdf
    ├── INSTALACAO.pdf
    ├── MANUAL_USUARIO.pdf
    └── ESPECIFICACOES_TECNICAS.pdf
```

## 🔧 Comandos Úteis

### Gerenciar Containers
```bash
cd /home/ubuntu/saas-agendamentos

# Ver status
docker-compose ps

# Ver logs
docker-compose logs -f

# Reiniciar
docker-compose restart

# Parar tudo
docker-compose down

# Iniciar
docker-compose up -d
```

### Backup e Restore
```bash
# Fazer backup
./scripts/backup.sh

# Listar backups
./scripts/restore.sh --list

# Restaurar backup
./scripts/restore.sh db_backup_20240101_120000.sql.gz
```

### Monitoramento
```bash
# Status do sistema
systemctl status nginx
docker-compose ps
ufw status

# Logs importantes
tail -f /var/log/nginx/error.log
docker-compose logs backend
```

## ⚙️ Configurações Importantes

### Arquivo .env
```bash
# Editar configurações
nano .env

# Principais variáveis:
DOMAIN=seudominio.com
DB_PASSWORD=senha-super-segura
JWT_SECRET=token-jwt-32-caracteres
EMAIL_USER=seu-email@gmail.com
EMAIL_PASS=senha-do-app
```

### Configurar Email
1. Acesse [Google App Passwords](https://myaccount.google.com/apppasswords)
2. Gere uma senha de app
3. Configure no .env:
   ```bash
   EMAIL_HOST=smtp.gmail.com
   EMAIL_USER=seu-email@gmail.com
   EMAIL_PASS=senha-gerada-pelo-google
   ```

## 🎯 Funcionalidades Principais

### Para Prestadores
- ✅ Página personalizada (seusite.com/p/seu-nome)
- ✅ Gerenciar serviços e preços
- ✅ Controlar agenda e horários
- ✅ Receber agendamentos online
- ✅ Dashboard com estatísticas

### Para Clientes
- ✅ Buscar prestadores por localização
- ✅ Agendar serviços online
- ✅ Receber confirmações por email
- ✅ Avaliar prestadores
- ✅ Histórico de agendamentos

### Para Administradores
- ✅ Gerenciar usuários e prestadores
- ✅ Moderar conteúdo
- ✅ Relatórios e estatísticas
- ✅ Configurar categorias

## 🔐 Segurança

### Configurações Aplicadas
- ✅ Firewall UFW configurado
- ✅ SSL Let's Encrypt
- ✅ Rate limiting no NGINX
- ✅ Headers de segurança
- ✅ Senhas criptografadas
- ✅ JWT para autenticação

### Manutenção
```bash
# Atualizar sistema
apt update && apt upgrade -y

# Renovar SSL (automático)
certbot renew --dry-run

# Backup automático (configurado)
crontab -l
```

## 📱 Responsividade

O sistema é totalmente responsivo e funciona em:
- 📱 Smartphones
- 📱 Tablets  
- 💻 Desktops
- 🖥️ Monitores grandes

## 🆘 Suporte Rápido

### Problemas Comuns

**Containers não iniciam:**
```bash
docker-compose down
docker-compose up -d --build
```

**SSL não funciona:**
```bash
# Verificar DNS
dig +short seudominio.com

# Renovar certificado
certbot --nginx -d seudominio.com
```

**Aplicação lenta:**
```bash
# Verificar recursos
htop
df -h
docker stats
```

**Erro 502:**
```bash
# Verificar backend
docker-compose logs backend
docker-compose restart backend
```

### Logs Importantes
```bash
# Aplicação
docker-compose logs -f backend

# NGINX
tail -f /var/log/nginx/error.log

# Sistema
tail -f /var/log/syslog
```

## 📞 Contato

- **Email**: suporte@seudominio.com
- **WhatsApp**: (11) 99999-9999
- **Documentação**: Arquivos PDF inclusos
- **GitHub**: Issues para bugs e sugestões

## 🎉 Próximos Passos

1. **Personalizar**: Edite cores, logos e textos
2. **Configurar Email**: Para notificações automáticas
3. **Adicionar Prestadores**: Convide profissionais
4. **Promover**: Divulgue sua plataforma
5. **Monitorar**: Acompanhe métricas e logs

---

**✅ Sistema pronto para uso em produção!**

Para informações detalhadas, consulte os PDFs da documentação inclusos no projeto.


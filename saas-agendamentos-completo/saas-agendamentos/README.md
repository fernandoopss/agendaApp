# 🚀 Sistema SaaS de Agendamento Online

Sistema completo de agendamento online para prestadores de serviços (cabeleireiros, manicures, mecânicos, etc.), permitindo que cada prestador tenha sua própria página de agendamento personalizada.

## 🏗️ Arquitetura

- **Backend**: NestJS + Prisma + PostgreSQL
- **Frontend**: Next.js + TailwindCSS
- **Banco de Dados**: PostgreSQL
- **Containerização**: Docker + Docker Compose
- **Servidor**: VPS Ubuntu com NGINX + SSL
- **Autenticação**: JWT

## 🔥 Funcionalidades

### 👤 Cliente (Usuário Final)
- ✅ Cadastro e login
- ✅ Buscar prestadores por nome, cidade ou categoria
- ✅ Visualizar serviços e horários disponíveis
- ✅ Agendar serviços
- ✅ Receber confirmações
- ✅ Painel com histórico de agendamentos

### 🧑‍💼 Prestador de Serviços
- ✅ Cadastro e login
- ✅ Página personalizada de agendamento
- ✅ Cadastro de serviços e preços
- ✅ Definição de horários de funcionamento
- ✅ Gestão de agendamentos (confirmar/cancelar)
- ✅ Painel de controle com clientes
- ✅ Relatórios e estatísticas

### 🛠️ Administrador
- ✅ Dashboard de controle geral
- ✅ Gerenciamento de prestadores
- ✅ Gerenciamento de usuários
- ✅ Relatórios e estatísticas globais
- ✅ Controle de planos (monetização)

## 📂 Estrutura do Projeto

```
saas-agendamentos/
├── backend/                 # API NestJS
│   ├── src/
│   │   ├── auth/           # Autenticação JWT
│   │   ├── users/          # Módulo de usuários
│   │   ├── providers/      # Módulo de prestadores
│   │   ├── appointments/   # Módulo de agendamentos
│   │   └── common/         # Utilitários comuns
│   ├── prisma/             # Schema e migrações
│   └── Dockerfile
├── frontend/               # Interface Next.js
│   ├── pages/              # Páginas da aplicação
│   ├── components/         # Componentes reutilizáveis
│   ├── styles/             # Estilos TailwindCSS
│   └── Dockerfile
├── nginx/                  # Configuração do proxy
│   ├── default.conf
│   └── ssl/
├── scripts/                # Scripts de deploy e backup
│   ├── backup.sh
│   ├── restore.sh
│   └── deploy.sh
├── docker-compose.yml      # Orquestração dos containers
└── README.md
```

## 🚀 Deploy Rápido

### Pré-requisitos
```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install docker.io docker-compose nginx certbot python3-certbot-nginx ufw git -y

# Configurar firewall
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```

### Instalação
```bash
# Clonar projeto
git clone <seu-repositorio>
cd saas-agendamentos

# Configurar variáveis de ambiente
cp .env.example .env
nano .env

# Subir containers
docker-compose up -d --build

# Configurar NGINX e SSL
sudo cp nginx/default.conf /etc/nginx/sites-available/default
sudo certbot --nginx -d seudominio.com
sudo systemctl restart nginx
```

## 🔒 Segurança

- ✅ HTTPS obrigatório via Let's Encrypt
- ✅ Firewall configurado (UFW)
- ✅ Autenticação JWT com refresh tokens
- ✅ Hash de senhas com bcrypt
- ✅ Validação de dados de entrada
- ✅ Rate limiting nas APIs

## 🌐 URLs do Sistema

- **Frontend**: `https://seudominio.com`
- **API**: `https://seudominio.com/api`
- **Página do Prestador**: `https://seudominio.com/p/[nome-prestador]`
- **Admin**: `https://seudominio.com/admin`

## 📊 Banco de Dados

O sistema utiliza PostgreSQL com as seguintes entidades principais:

- **Users**: Clientes do sistema
- **Providers**: Prestadores de serviços
- **Services**: Serviços oferecidos
- **Appointments**: Agendamentos
- **Categories**: Categorias de serviços
- **Schedules**: Horários de funcionamento

## 🔧 Desenvolvimento

### Backend (NestJS)
```bash
cd backend
npm install
npm run start:dev
```

### Frontend (Next.js)
```bash
cd frontend
npm install
npm run dev
```

### Banco de Dados
```bash
# Executar migrações
npx prisma migrate dev

# Visualizar dados
npx prisma studio
```

## 📱 Responsividade

O sistema é totalmente responsivo e otimizado para:
- 📱 Mobile (smartphones)
- 📱 Tablet
- 💻 Desktop
- 🖥️ Telas grandes

## 🎨 Personalização

Cada prestador pode personalizar:
- ✅ Cores da página
- ✅ Logo/foto de perfil
- ✅ Descrição dos serviços
- ✅ Horários de funcionamento
- ✅ Política de cancelamento

## 📈 Monetização

O sistema suporta diferentes planos:
- **Gratuito**: Até 50 agendamentos/mês
- **Básico**: Até 200 agendamentos/mês
- **Premium**: Agendamentos ilimitados + recursos extras

## 🔄 Backup e Restore

```bash
# Backup automático
./scripts/backup.sh

# Restaurar backup
./scripts/restore.sh backup-2024-01-01.sql
```

## 📞 Suporte

Para dúvidas ou suporte técnico:
- 📧 Email: suporte@seudominio.com
- 💬 WhatsApp: (11) 99999-9999
- 📖 Documentação: https://docs.seudominio.com

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**Desenvolvido com ❤️ para facilitar a vida dos prestadores de serviços brasileiros.**


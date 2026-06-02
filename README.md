# 📚 ToonArchive

Aplicativo mobile de leitura de mangás, manhwas e HQs desenvolvido em Flutter.
Funciona online com sincronização em nuvem e offline com banco de dados local.

---

## Visão Geral

O ToonArchive permite que usuários leiam obras, favoritem capítulos, façam downloads para leitura offline e participem de comunidades de fãs via chat. O app usa uma arquitetura **offline-first**: todas as ações são salvas primeiro no SQLite local e sincronizadas com o Supabase quando há conexão.

---

## Tecnologias Usadas

| Tecnologia | Para quê |
|---|---|
| **Flutter** | Framework do app (Android, iOS, Web, Desktop) |
| **Firebase Auth** | Autenticação de usuários (email/senha e Google) |
| **Supabase** | Banco de dados em nuvem e storage de imagens |
| **SQLite (sqflite)** | Banco local para funcionamento offline |
| **Hugging Face** | Recomendação de obras por IA |
| **Giphy API** | GIFs no chat das comunidades |

---

## Funcionalidades

- **Login e Cadastro** — por email/senha ou Google. Funciona offline (cria conta local e sincroniza depois)
- **Biblioteca de Obras** — lista todas as obras com capa, autor, gêneros e status
- **Detalhes da Obra** — capítulos, descrição expandível, gêneros, botão de favoritar e download
- **Leitura de Capítulos** — modo rolagem ou modo clique, suporte a zoom, comentários com texto/GIF/foto/sticker
- **Downloads Offline** — baixa capítulos página por página; disponíveis sem internet
- **Favoritos** — salva obras favoritas sincronizadas com a nuvem
- **Recomendações por IA** — sugere obras baseadas nos favoritos do usuário usando embeddings semânticos
- **Comunidades** — grupos de chat com suporte a texto, GIF, stickers e fotos
- **Tema Claro/Escuro** — alternável a qualquer momento pelo perfil do usuário

---

## Estrutura do Projeto

```
lib/
├── main.dart                    # Ponto de entrada do app
├── core/
│   ├── database/
│   │   ├── database_helper.dart # Gerencia o SQLite local
│   │   └── supabase_client.dart # Inicializa o cliente Supabase
│   ├── sync/
│   │   └── sync_service.dart    # Sincroniza dados offline → Supabase
│   └── helpers/
│       └── app_config.dart      # Lê variáveis do .env
├── models/                      # Classes de dados (Obra, Capitulo, Usuario...)
├── repositories/                # Acesso a dados (SQLite + Supabase com fallback)
├── services/                    # Lógica de negócio (auth, download, recomendação)
├── screens/                     # Páginas do app (home, leitura, login...)
├── routes/
│   └── app_routes.dart          # Definição de rotas de navegação
└── widgets/
    └── obra_card.dart           # Card reutilizável de obra
```

---

## Como Funciona a Sincronização Offline

1. O usuário realiza uma ação (favoritar, salvar progresso, etc.) **sem internet**
2. A ação é salva no **SQLite** imediatamente
3. Uma entrada é criada na tabela `sync_log` com o payload da operação
4. Quando a internet é restaurada, o `SyncService` lê o `sync_log` e envia cada operação ao **Supabase** em ordem cronológica
5. Operações bem-sucedidas são marcadas como sincronizadas

**Tabelas que geram sync_log:** `favoritos`, `downloads`, `progresso_leitura`, `historico_leitura`, `avaliacoes`

**Tabelas somente leitura local:** `obras`, `capitulos`, `paginas`, `comentarios`

---

## Como Rodar o Projeto

### Pré-requisitos

- Flutter SDK instalado ([flutter.dev](https://flutter.dev))
- Conta no [Firebase](https://firebase.google.com) com projeto configurado
- Conta no [Supabase](https://supabase.com) com projeto configurado
- Chave de API do [Hugging Face](https://huggingface.co) (opcional, para recomendações)
- Chave de API do [Giphy](https://developers.giphy.com) (opcional, para GIFs no chat)

### Passo a Passo

**1. Clone o repositório e instale as dependências:**
```bash
git clone <url-do-repositorio>
cd toonarchive
flutter pub get
```

**2. Configure as variáveis de ambiente:**

Crie um arquivo `.env` na raiz do projeto:
```env
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_KEY=sua_chave_anonima_supabase
HF_API_KEY=hf_sua_chave_huggingface
GIPHY_API_KEY=sua_chave_giphy
GROUP_ID=SF-GP-01
```

**3. Configure o Firebase:**

- Gere o arquivo `google-services.json` (Android) e/ou `GoogleService-Info.plist` (iOS) no console do Firebase
- Coloque-os nas pastas `android/app/` e `ios/Runner/` respectivamente
- O arquivo `lib/firebase_options.dart` já está gerado pelo FlutterFire CLI

**4. Configure o banco de dados Supabase:**

Execute o arquivo `sqlite_create_tables.sql` no **SQL Editor do Supabase** para criar as tabelas na nuvem. As mesmas tabelas são criadas automaticamente no SQLite local ao iniciar o app.

**5. Execute o app:**
```bash
flutter run
```

---

## Banco de Dados

O app usa as seguintes tabelas (tanto no SQLite quanto no Supabase):

| Tabela | O que armazena |
|---|---|
| `usuarios` | Dados de perfil e autenticação |
| `obras` | Mangás, HQs e outras publicações |
| `capitulos` | Capítulos de cada obra |
| `paginas` | Imagens de cada capítulo |
| `favoritos` | Obras favoritadas por usuário |
| `downloads` | Capítulos baixados para offline |
| `progresso_leitura` | Último capítulo/página lida por obra |
| `historico_leitura` | Capítulos concluídos (máx. 100 por usuário) |
| `generos` | Catálogo de gêneros (ação, romance, etc.) |
| `obra_generos` | Relacionamento obra ↔ gênero |
| `comentarios` | Comentários nos capítulos |
| `sync_log` | Fila de operações offline pendentes |

---

## Recomendações por IA

O sistema de recomendação usa **embeddings semânticos** do modelo `paraphrase-multilingual-MiniLM-L12-v2` (Hugging Face):

1. Gera um texto de perfil com os títulos e gêneros das obras favoritadas
2. Gera textos descritivos para cada obra candidata
3. Calcula similaridade de cosseno entre o perfil e as candidatas
4. Aplica um multiplicador de overlap de gêneros para garantir afinidade
5. Retorna as obras com maior score final

Se não houver conexão ou chave de API, usa um **fallback local** baseado na frequência de gêneros nos favoritos.

---

## Variáveis de Ambiente

| Variável | Obrigatório | Descrição |
|---|---|---|
| `SUPABASE_URL` | ✅ | URL do projeto Supabase |
| `SUPABASE_KEY` | ✅ | Chave anônima (anon key) do Supabase |
| `HF_API_KEY` | ⬜ | Chave do Hugging Face para recomendações por IA |
| `GIPHY_API_KEY` | ⬜ | Chave do Giphy para GIFs nos chats |
| `GROUP_ID` | ⬜ | Identificador de grupo padrão |

---

## Observações

- O app foi desenvolvido por estudantes como projeto acadêmico
- As chaves de API nos arquivos de exemplo **não devem ser commitadas** no repositório (o `.gitignore` já ignora o `.env`)
- O arquivo `firebase_options.dart` contém chaves públicas do Firebase que são seguras para versionar

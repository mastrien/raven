# 🐦 Raven

> **Privacidade sob pressão.** Um protótipo de comunicação segura com foco em negação plausível e proteção contra coerção física.

## 📌 Visão Geral

O **Raven** é um aplicativo de mensagens desenvolvido em Flutter que vai além da criptografia convencional. Ele foi projetado para cenários onde o usuário pode ser forçado a desbloquear seu dispositivo, oferecendo um sistema de "múltiplas realidades" baseado na senha de acesso.

## 🔑 Funcionalidade Core: Negação Plausível

O diferencial do projeto reside no seu sistema de autenticação inteligente. Dependendo do PIN inserido na tela de bloqueio, o aplicativo se comporta de maneiras diferentes:

| PIN | Destino | Descrição |
| :--- | :--- | :--- |
| **`2580`** | **Cofre Real** | Acesso completo às conversas privadas, seguras e criptografadas. |
| **`0000`** | **Ambiente Discreto** | Abre uma interface "isca" com conversas neutras e inofensivas. |
| **`9999`** | **Modo Emergência** | Simula um bloqueio de segurança e redireciona para o ambiente discreto. |

## 🚀 Tech Stack

- **Framework:** [Flutter](https://flutter.dev/) (Canal Beta, SDK ^3.10.0)
- **Linguagem:** Dart
- **Backend:** Firebase (Core, Firestore, Realtime Database)
- **UI:** Material 3 com design customizado focado em legibilidade e discrição.

## 📂 Estrutura do Projeto

A lógica principal do protótipo está concentrada em `src/lib/main.dart`, estruturada da seguinte forma:

- `LockScreen`: Gerencia a lógica de PINs e a transição entre estados.
- `RavenShell`: O container principal de navegação.
- `ChatListScreen`: Lista conversas dinamicamente baseada no `decoyMode`.
- `SecurityScreen`: Dashboard demonstrativo de camadas extras de proteção.

## 🎨 Design e Estratégia

O conceito visual e o mapeamento de UX do projeto podem ser encontrados na apresentação oficial:
👉 **[Apresentação Raven no Canva](https://canva.link/s55icoge4wix186)** *(Referenciado em Raven.docx)*

## 🛠️ Como Executar

1.  **Pré-requisitos:** Certifique-se de ter o Flutter instalado e configurado em seu ambiente.
2.  **Instalar dependências:**
    ```bash
    cd src
    flutter pub get
    ```
3.  **Rodar o projeto:**
    ```bash
    flutter run
    ```

## 📋 Roadmap de Desenvolvimento

- [x] Protótipo de UI de alta fidelidade.
- [x] Lógica de negação plausível (Modo Decoy).
- [ ] Implementação de criptografia ponta-a-ponta (E2EE).
- [ ] Troca dinâmica de ícone (Camuflagem de App).
- [ ] Integração total com Firebase para mensagens em tempo real.
- [ ] Minimização agressiva de metadados locais.

---
*Este é um projeto de prova de conceito (PoC). O uso em ambientes de produção exige auditoria de segurança e implementação de armazenamento seguro de chaves.*

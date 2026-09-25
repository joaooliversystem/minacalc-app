# MinaCalc Pro — Fase 3 (Flutter nativo)

Objetivo: aplicativo Android/iOS nativo em Flutter, sem WebView, espelhando o fluxo operacional do MinaCalc Web e usando a API criada na Fase 2.

## Regras implementadas

- Primeiro login no aparelho obrigatoriamente online.
- Após autenticação válida, sessão e dados necessários ficam disponíveis offline até a expiração/invalidação da sessão.
- SQLite local armazena planos, operações, equipes, checklists, mapa, rascunhos e fila de sincronização.
- Token de autenticação fica em armazenamento seguro do sistema, não no SQLite.
- Alterações offline entram em fila e sincronizam automaticamente ao recuperar acesso real ao servidor.
- Mutations possuem IDs únicos e o servidor trata repetição como idempotente.
- Fotos são aceitas em tamanho original pelo app, copiadas/otimizadas localmente e enviadas individualmente após a operação sincronizar.
- GPS busca múltiplas leituras e mantém a de melhor precisão obtida durante a amostragem.
- Mapa interno: MapLibre + OpenFreeMap, sem chave de API.
- Área do mapa pode ser baixada previamente como Offline Region do MapLibre.
- Marcadores criados online ou offline são sincronizados com a versão web.
- Marcadores sensíveis apenas registram a posição informada/capturada; o aplicativo não recomenda posicionamento.
- Status sempre visível: Online, Offline, Sincronizando ou Erro.

## Fluxo de campo nativo

Entrada institucional → termo → login online → A executar → dados → checklist → fotos → GPS → observações → assinatura → revisão → concluir localmente → sincronização automática.

## Estrutura

- `data/local_db.dart`: SQLite e fila local.
- `data/api_client.dart`: API/token/sync/upload de evidência.
- `services/sync_engine.dart`: push/pull incremental, idempotência e fila.
- `services/offline_map_service.dart`: mapas offline MapLibre.
- `services/location_service.dart`: GPS de melhor precisão.
- `services/media_service.dart`: câmera/galeria, cópia e otimização.
- `ui/screens/operation_wizard.dart`: fluxo de campo sem depender da internet.
- `ui/screens/map_screen.dart`: mapa interno e marcações.

## Importante para a Fase 4

O ambiente atual de desenvolvimento desta conversa não possui Flutter SDK/Android SDK instalados, então o APK não é gerado nesta fase. Na Fase 4 será necessário executar `flutter create`/build sobre esta base, aplicar permissões Android, resolver qualquer ajuste de API de plugin apontado pelo `flutter analyze`, executar testes em emulador/aparelho e somente então assinar/gerar o APK final.

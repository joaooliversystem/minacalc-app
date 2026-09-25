# MinaCalc Pro 2.9.0 — aplicativo Flutter nativo com paridade mobile web

Aplicativo de campo nativo, sem WebView, sincronizado com a API do MinaCalc Pro.

## Fluxo

1. O primeiro login do aparelho exige internet.
2. Após autenticar, o app baixa o snapshot permitido ao usuário e mantém banco SQLite local.
3. A experiência visual/navegação segue o mobile web: dashboard, menu, barra inferior, planos, trabalhos, relatórios e cadastros por perfil.
4. Planos, empresas, equipes, usuários, checklists, aprovações, configurações operacionais e operações de campo podem ser registrados offline conforme a permissão do perfil.
5. Alterações offline entram em uma fila SQLite local/idempotente.
6. Ao recuperar acesso real ao servidor, o app envia a fila e baixa alterações incrementais.
7. Conflitos de versão ficam separados para revisão, sem sobrescrita silenciosa.
8. Senhas, SMTP e ações que manipulam segredos continuam online por segurança.

## Mapa

- MapLibre nativo dentro do app.
- OpenFreeMap no modo online, sem chave de API.
- Área operacional pequena pode ser baixada previamente para uso offline.
- GPS atual, precisão estimada e marcadores por categoria.
- Pontos de itens controlados são apenas registros informados/capturados pelo responsável; o app não recomenda posicionamento.
- Atribuição OpenStreetMap/OpenFreeMap permanece visível.

## Android

- Package: `br.com.minacalc.pro`
- Android mínimo: API 23.
- Permissões: internet, estado da rede, câmera e localização aproximada/precisa durante o uso.
- Não solicita localização em segundo plano.
- Backup automático Android desativado para proteger o armazenamento seguro de sessão.

## Compilação

Com Flutter 3.47.5 instalado:

`flutter pub get`

`flutter analyze --no-fatal-warnings --no-fatal-infos`

`flutter test`

`flutter build apk --release`

O APK de homologação usa a assinatura de debug configurada no projeto. Antes de publicação na Play Store, configure um keystore de produção.

Também existe `.github/workflows/android-apk.yml` para compilar automaticamente o APK em GitHub Actions.

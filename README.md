# MinaCalc Pro 2.8.0 — aplicativo Flutter nativo

Aplicativo de campo nativo, sem WebView, sincronizado com a API do MinaCalc Pro.

## Fluxo

1. O primeiro login do aparelho exige internet.
2. Após autenticar, o app baixa o snapshot permitido ao usuário e mantém banco SQLite local.
3. Em campo, planos disponíveis, checklist, fotos, GPS, observações, assinatura e conclusão funcionam sem internet.
4. Alterações offline entram em uma fila local idempotente.
5. Ao recuperar acesso real ao servidor, o app envia a fila e baixa alterações incrementais.
6. Conflitos de versão ficam separados para revisão, sem sobrescrita silenciosa.

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

`flutter analyze`

`flutter test`

`flutter build apk --release`

O APK de homologação usa a assinatura de debug configurada no projeto. Antes de publicação na Play Store, configure um keystore de produção.

Também existe `.github/workflows/android-apk.yml` para compilar automaticamente o APK em GitHub Actions.

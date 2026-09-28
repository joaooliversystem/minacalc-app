# MinaCalc Pro 2.14.2 — Flutter / Android

Aplicativo nativo para operação de campo com primeiro login online e continuidade offline após sincronização inicial.

## Versão
- Flutter app: `2.14.2+2142`
- API esperada: MinaCalc Pro Web/API `2.14.2`
- Application ID: `br.com.minacalc.pro`

## Recursos consolidados
- Login e sessão segura.
- Snapshot/sincronização com a API.
- Motor de fórmulas publicado, cacheado para uso offline.
- Plano de Fogo e resultados com rastreabilidade da versão das fórmulas.
- Operação de campo, APFF, checklist, equipe, furos/perfuração, explosivos e boosters.
- Fotos, GPS, assinatura, observações e rascunhos offline.
- Sincronização online → offline → online com idempotência e tratamento de conflitos.
- Visualização do relatório final consolidado.
- Mapa com MapLibre/OpenFreeMap, sem chave paga.

## Build APK de homologação
Linux/macOS:
```bash
./BUILD_APK.sh
```
Windows:
```bat
BUILD_APK.bat
```

## Build AAB para Play Store
1. Copie `android/key.properties.example` para `android/key.properties`.
2. Informe seu keystore de upload real.
3. Execute:

Linux/macOS:
```bash
./BUILD_AAB.sh
```
Windows:
```bat
BUILD_AAB.bat
```

Sem `key.properties`, o build release usa a assinatura debug somente para homologação. Para Play Store, use sempre o keystore de produção/upload.

## API
Por padrão o app usa:
`https://desenvolvimento.joaoprogramador.site/projetos/minacalc/api.php`

Para outra instalação, compile informando:
```bash
flutter build apk --release --dart-define=MINACALC_API_URL=https://SEU-DOMINIO/api.php
```

## Observação de validação
As fórmulas técnicas marcadas como pendentes no servidor não são aplicadas automaticamente pelo app. O app utiliza somente versões publicadas e sincronizadas.

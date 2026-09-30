# MinaCalc Pro 2.16.0 — Flutter / Android

Aplicativo nativo para operação de campo com primeiro login online e continuidade offline após sincronização inicial.

## Versão
- Flutter app: `2.16.0+2160`
- API esperada: MinaCalc Pro Web/API `2.16.0`
- Application ID: `br.com.minacalc.pro`

## Recursos consolidados
- Login e sessão segura.
- Snapshot/sincronização com a API.
- Motor de fórmulas publicado, cacheado para uso offline.
- Cadastros dinâmicos sincronizados e mantidos localmente para operação offline.
- Regra automática bombeado x encartuchado com cálculo de kg/m, kg/furo, volume/furo, razão e carga total.
- Revisão operacional com planejado x executado, carga real/furo e razão real.
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
`https://minacalcpro.com.br/api.php`

Para outra instalação, compile informando:
```bash
flutter build apk --release --dart-define=MINACALC_API_URL=https://SEU-DOMINIO/api.php
```

## Observação de validação
As fórmulas técnicas marcadas como pendentes no servidor não são aplicadas automaticamente pelo app. O app utiliza somente versões publicadas e sincronizadas.


## Cobrança PIX 2.16.0
- Área “Plano e PIX” para clientes do MinaCalc Pro.
- Consulta e geração de cobrança sempre pelo backend Web/API; nenhuma credencial do MeuAssistente.pro é embutida no APK.
- Exibe QR Code/PIX copia e cola quando disponibilizados pela API; fallback para checkout externo.
- Status financeiro fica em cache local somente para consulta offline; criação/atualização de cobrança exige internet.

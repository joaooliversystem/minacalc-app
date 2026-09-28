MinaCalc Pro 2.14.2 - Hotfix GitHub Build

Causa do erro:
lib/ui/screens/home_screen.dart usava Container(minWidth: 16), parametro inexistente no Flutter.

Correcao:
Container(constraints: const BoxConstraints(minWidth: 16), ...)

Workflow:
.github/workflows/android-apk.yml agora tambem executa em push na branch main.

Arquivos para substituir no repositorio:
- lib/ui/screens/home_screen.dart
- .github/workflows/android-apk.yml

Apos fazer commit/push na main, o Build Android APK inicia automaticamente.

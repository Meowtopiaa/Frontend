# Meowtopia — FrontEnd (Flutter)

Repositori aplikasi mobile & web Flutter untuk **Meowtopia Super App** (dipisahkan dari monorepo SuperAppMeowtopia).
Acuan kebutuhan: docs/PRD.md (PRD Final v1.1).

## Struktur Branch
- main: Branch produksi/rilis utama.
- development: Branch integrasi pengembangan (base dari semua branch kelompok).
- Branch kelompok (parent dari development):
  - 	eam/acumalaka (lib/features/feeding_spot/, auth & base design)
  - 	eam/super-sub (lib/features/cat_hunter/)
  - 	eam/enigma (lib/features/cat_adoption/)
  - 	eam/optimind (lib/features/incident_report/)
  - 	eam/rekans-caps (lib/features/cat/, lib/features/cat_identification/)

## Menjalankan Lokal
```bash
flutter pub get
flutter run --dart-define=MEOWTOPIA_API_URL=http://10.0.2.2:8000/api/v1 --dart-define=MEOWTOPIA_DEMO=false
```

## Verifikasi Sebelum PR
```bash
flutter analyze
flutter test
```
# mymovie

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Konfigurasi Firebase Aman

Karena repo ini akan disebarkan ke publik, semua nilai sensitif ditarik keluar dari
source control. Kamu perlu menyediakan konfigurasi Firebase secara lokal sebelum
menjalankan atau membangun aplikasi.

### 1. File `google-services.json`

- Unduh file tersebut dari Firebase Console > Project settings > Aplikasi Android.
- Taruh di `android/app/google-services.json` sebelum menjalankan `flutter run`.
- File ini sudah diabaikan oleh `.gitignore`, jadi pastikan tidak ikut `git add`.

### 2. Variabel lingkungan (`--dart-define`)

File `lib/firebase_options.dart` sekarang menuntut nilai konfigurasi melalui `--dart-define`.
Berikut nama variabel yang harus diatur saat menjalankan perintah Flutter:

1. `FIREBASE_ANDROID_API_KEY`
2. `FIREBASE_ANDROID_APP_ID`
3. `FIREBASE_ANDROID_MESSAGING_SENDER_ID`
4. `FIREBASE_ANDROID_PROJECT_ID`
5. `FIREBASE_ANDROID_STORAGE_BUCKET`
6. `FIREBASE_WEB_API_KEY`
7. `FIREBASE_WEB_APP_ID`
8. `FIREBASE_WEB_MESSAGING_SENDER_ID`
9. `FIREBASE_WEB_PROJECT_ID`
10. `FIREBASE_WEB_AUTH_DOMAIN`
11. `FIREBASE_WEB_STORAGE_BUCKET`
12. `FIREBASE_WEB_MEASUREMENT_ID`

Kalau kamu menggunakan CI, set variabel ini di environment build agar `flutter build`
atau `flutter test` tidak gagal karena placeholder.

### Contoh perintah

```bash
flutter run \
	--dart-define=FIREBASE_ANDROID_API_KEY=<android-api-key> \
	--dart-define=FIREBASE_ANDROID_APP_ID=<android-app-id> \
	--dart-define=FIREBASE_ANDROID_MESSAGING_SENDER_ID=<android-messaging-sender-id> \
	--dart-define=FIREBASE_ANDROID_PROJECT_ID=<android-project-id> \
	--dart-define=FIREBASE_ANDROID_STORAGE_BUCKET=<android-storage-bucket>
```

Untuk build web, tambahkan semua variabel `FIREBASE_WEB_*` dengan `--dart-define`
ketika menjalankan `flutter build web`.

Ganti placeholder `<...>` di atas dengan nilai sebenarnya. Cantumkan `--dart-define`
saat menjalankan `flutter build web`, `flutter build apk`, atau instruksi release
lainnya.


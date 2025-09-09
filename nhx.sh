#!/data/data/com.termux/files/usr/bin/bash
# Neo-Hydraulik: One-shot Fix & Build (Termux)
set -euo pipefail

ROOT="$(pwd)"
APP="$ROOT/app"
AND="$ROOT/android"
APPAND="$AND/app"
SET="$ROOT/settings.gradle"
APPBLD="$APPAND/build.gradle"

say(){ printf "\033[36m%s\033[0m\n" "$*"; }
ok(){ printf "\033[32m%s\033[0m\n" "$*"; }
fail(){ printf "\033[31m%s\033[0m\n" "$*"; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

# 0) Env
have node || fail "Node fehlt (Termux: pkg install nodejs)"
have npm  || fail "npm fehlt (Termux: pkg install nodejs)"
ok "Node $(node -v) / npm $(npm -v)"

# 1) Minimal Web-App/Configs (nur wenn fehlen)
mkdir -p "$APP/src"
[ -f "$ROOT/index.html" ] || cat > "$ROOT/index.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/></head><body><div id="root"></div><script type="module" src="/app/src/main.tsx"></script></body></html>
HTML
[ -f "$ROOT/tsconfig.json" ] || cat > "$ROOT/tsconfig.json" <<'JSON'
{ "compilerOptions": { "target":"ES2022","module":"ESNext","moduleResolution":"Bundler","jsx":"react-jsx","strict":true,"types":["vite/client"] }, "include":["app"] }
JSON
[ -f "$ROOT/vite.config.ts" ] || cat > "$ROOT/vite.config.ts" <<'TS'
import { defineConfig } from 'vite'
export default defineConfig({ build:{ outDir:'dist' }})
TS
[ -f "$APP/src/main.tsx" ] || cat > "$APP/src/main.tsx" <<'TSX'
const root=document.getElementById('root')!; root.innerHTML="<b>Neo-Hydraulik</b>"
TSX

# 2) package.json + deps
if [ ! -f "$ROOT/package.json" ]; then
cat > "$ROOT/package.json" <<'JSON'
{
  "name": "neo-hydraulik",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -b || true && vite build",
    "android:sync":"npx cap sync android"
  },
  "dependencies": {
    "@capacitor/core":"^5.7.8",
    "@capacitor/android":"^5.7.8",
    "react":"^18.3.1",
    "react-dom":"^18.3.1"
  },
  "devDependencies": { "typescript":"^5.5.4","vite":"^4.5.0" }
}
JSON
fi
npm install

# 3) Capacitor config nach app/
mkdir -p "$APP"
cat > "$APP/capacitor.config.ts" <<'TS'
import type { CapacitorConfig } from '@capacitor/cli'
const config: CapacitorConfig = {
  appId: 'com.neohydraulik.game',
  appName: 'NeoHydraulik',
  webDir: 'dist',
  android: { path: 'android' }
}
export default config
TS

# 4) Android-Projekt sicherstellen
if [ ! -d "$AND" ]; then
  npx cap add android
fi

# 5) settings.gradle minimal (nur :app)
cat > "$SET" <<'GRADLE'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS); repositories { google(); mavenCentral() } }
rootProject.name = "neo-hydraulik"
include(":app")
project(":app").projectDir = new File("android/app")
GRADLE

# 6) android/app/build.gradle auf Maven-Capacitor pinnen
CAPV="$(node -e "console.log(require('./node_modules/@capacitor/android/package.json').version)")"
mkdir -p "$APPAND/src/main"
cat > "$APPBLD" <<EOF
plugins { id "com.android.application" }
android {
  namespace "com.neohydraulik.game"
  compileSdk 34
  defaultConfig { applicationId "com.neohydraulik.game"; minSdk 24; targetSdk 34; versionCode 1; versionName "1.0" }
  buildTypes { release { minifyEnabled false; proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),'proguard-rules.pro' } debug { minifyEnabled false } }
  compileOptions { sourceCompatibility JavaVersion.VERSION_17; targetCompatibility JavaVersion.VERSION_17 }
}
dependencies {
  implementation "androidx.core:core-ktx:1.13.1"
  implementation "androidx.appcompat:appcompat:1.7.0"
  implementation "com.google.android.material:material:1.12.0"
  implementation "com.getcapacitor:capacitor-android:${CAPV}"
}
EOF

# 7) Web bauen + sync
npm run build
npx cap sync android

# 8) Gradle bauen (Debug APK)
if [ -x "$ROOT/gradlew" ]; then
  ./gradlew --no-daemon :app:assembleDebug
else
  (cd android && ./gradlew --no-daemon :app:assembleDebug)
fi

APK="$APPAND/build/outputs/apk/debug/app-debug.apk"
[ -f "$APK" ] && ok "APK fertig: $APK" || fail "Build fehlgeschlagen – siehe vorherigen Fehlerblock."

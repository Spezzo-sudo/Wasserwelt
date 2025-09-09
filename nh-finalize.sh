#!/bin/bash
set -e

CAP_VERSION=$(node -p "require('./node_modules/@capacitor/android/package.json').version" 2>/dev/null || echo '5.7.8')

if [ -f app/android/app/build.gradle ]; then
  ANDROID_ROOT="app/android"
  APP_ANDROID_DIR="app/android/app"
elif [ -f android/app/build.gradle ]; then
  ANDROID_ROOT="android"
  APP_ANDROID_DIR="android/app"
else
  echo "Android project not found"
  exit 1
fi

echo "Using Android module at $APP_ANDROID_DIR"

cat > settings.gradle <<EOF2
pluginManagement {
  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}
dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
  repositories {
    google()
    mavenCentral()
  }
}
rootProject.name = "neo-hydraulik"
include(":app")
project(":app").projectDir = new File("$APP_ANDROID_DIR")
EOF2

cat > "$ANDROID_ROOT/settings.gradle" <<EOF2
include ':app'
EOF2

cat > "$APP_ANDROID_DIR/build.gradle" <<EOF2
plugins { id 'com.android.application' }

android {
  namespace 'com.neohydraulik.game'
  compileSdk 34
  defaultConfig {
    applicationId 'com.neohydraulik.game'
    minSdk 24
    targetSdk 34
    versionCode 1
    versionName '1.0'
  }
  buildTypes {
    release {
      minifyEnabled false
      proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
    debug { minifyEnabled false }
  }
  compileOptions {
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
  }
}

java {
  toolchain {
    languageVersion = JavaLanguageVersion.of(17)
  }
}

dependencies {
  implementation 'androidx.core:core-ktx:1.13.1'
  implementation 'androidx.appcompat:appcompat:1.7.0'
  implementation 'com.google.android.material:material:1.12.0'
  implementation "com.getcapacitor:capacitor-android:${CAP_VERSION}"
}

apply from: 'capacitor.build.gradle'
EOF2

cat > "$APP_ANDROID_DIR/capacitor.build.gradle" <<'EOF2'
android {
  compileOptions {
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
  }
}

def cordovaVars = file("../capacitor-cordova-android-plugins/cordova.variables.gradle")
if (cordovaVars.exists()) {
  apply from: cordovaVars
}

dependencies {

}

if (hasProperty('postBuildExtras')) {
  postBuildExtras()
}
EOF2

cat > app/capacitor.config.ts <<'EOF2'
import type { CapacitorConfig } from '@capacitor/cli';
const config: CapacitorConfig = {
  appId: 'com.neohydraulik.game',
  appName: 'NeoHydraulik',
  webDir: 'dist',
  android: { projectPath: 'android' }
};
export default config;
EOF2

mkdir -p app/src/core app/src/state
cat > app/src/core/HexMath.ts <<'EOF2'
export interface Axial { q: number; r: number; }
export interface Cube { x: number; y: number; z: number; }

export const directions: Axial[] = [
  { q: 1, r: 0 },
  { q: 1, r: -1 },
  { q: 0, r: -1 },
  { q: -1, r: 0 },
  { q: -1, r: 1 },
  { q: 0, r: 1 }
];

export function axialToCube({ q, r }: Axial): Cube {
  const x = q;
  const z = r;
  const y = -x - z;
  return { x, y, z };
}

export function cubeToAxial({ x, z }: Cube): Axial {
  return { q: x, r: z };
}

export function neighbors(a: Axial): Axial[] {
  return directions.map(d => ({ q: a.q + d.q, r: a.r + d.r }));
}

export function distance(a: Axial, b: Axial): number {
  const ac = axialToCube(a);
  const bc = axialToCube(b);
  return Math.max(
    Math.abs(ac.x - bc.x),
    Math.abs(ac.y - bc.y),
    Math.abs(ac.z - bc.z)
  );
}

function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function cubeLerp(a: Cube, b: Cube, t: number): Cube {
  return {
    x: lerp(a.x, b.x, t),
    y: lerp(a.y, b.y, t),
    z: lerp(a.z, b.z, t)
  };
}

export function line(a: Axial, b: Axial): Axial[] {
  const N = distance(a, b);
  const ac = axialToCube(a);
  const bc = axialToCube(b);
  const results: Axial[] = [];
  for (let i = 0; i <= N; i++) {
    const p = cubeLerp(ac, bc, i / N);
    results.push(cubeToAxial({
      x: Math.round(p.x),
      y: Math.round(p.y),
      z: Math.round(p.z)
    }));
  }
  return results;
}

export function ring(center: Axial, radius: number): Axial[] {
  if (radius === 0) return [center];
  const results: Axial[] = [];
  let cube = axialToCube({
    q: center.q + directions[4].q * radius,
    r: center.r + directions[4].r * radius
  });
  for (let i = 0; i < 6; i++) {
    for (let j = 0; j < radius; j++) {
      results.push(cubeToAxial(cube));
      const dir = axialToCube(directions[i]);
      cube = { x: cube.x + dir.x, y: cube.y + dir.y, z: cube.z + dir.z };
    }
  }
  return results;
}

interface Node { pos: Axial; g: number; f: number; parent?: Node; }

export function aStar(start: Axial, goal: Axial, passable: (h: Axial) => boolean): Axial[] {
  const open: Node[] = [{ pos: start, g: 0, f: distance(start, goal) }];
  const closed = new Set<string>();
  const key = (p: Axial) => `${p.q},${p.r}`;

  while (open.length > 0) {
    open.sort((a, b) => a.f - b.f);
    const current = open.shift()!;
    if (current.pos.q === goal.q && current.pos.r === goal.r) {
      const path: Axial[] = [];
      let n: Node | undefined = current;
      while (n) {
        path.push(n.pos);
        n = n.parent;
      }
      return path.reverse();
    }
    closed.add(key(current.pos));
    for (const npos of neighbors(current.pos)) {
      if (!passable(npos) || closed.has(key(npos))) continue;
      const g = current.g + 1;
      const existing = open.find(n => n.pos.q === npos.q && n.pos.r === npos.r);
      if (existing && g >= existing.g) continue;
      const h = distance(npos, goal);
      const node: Node = { pos: npos, g, f: g + h, parent: current };
      if (!existing) {
        open.push(node);
      } else {
        existing.g = g;
        existing.f = g + h;
        existing.parent = current;
      }
    }
  }
  return [];
}
EOF2

cat > app/src/core/TickScheduler.ts <<'EOF2'
type TickHandler = (tick: number) => void;

export class TickScheduler {
  private accumulator = 0;
  private tick = 0;
  private handlers: TickHandler[] = [];

  constructor(private readonly stepMs = 50) {}

  update(dtMs: number): void {
    this.accumulator += dtMs;
    let loops = 0;
    while (this.accumulator >= this.stepMs && loops < 8) {
      this.accumulator -= this.stepMs;
      this.tick++;
      for (const h of this.handlers) h(this.tick);
      loops++;
    }
    if (loops === 8) {
      this.accumulator = 0;
    }
  }

  onTick(cb: TickHandler): () => void {
    this.handlers.push(cb);
    return () => {
      this.handlers = this.handlers.filter(h => h !== cb);
    };
  }
}
EOF2

cat > app/src/state/FirestoreAdapter.ts <<'EOF2'
import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import {
  getFirestore,
  collection,
  onSnapshot,
  addDoc,
  QuerySnapshot,
  DocumentData
} from 'firebase/firestore';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID
};

type Unsub = () => void;

export class FirestoreAdapter {
  private app = initializeApp(firebaseConfig);
  private db = getFirestore(this.app);
  private auth = getAuth(this.app);
  private unsubs: Unsub[] = [];

  constructor() {
    signInAnonymously(this.auth).catch(console.error);
  }

  listenPlayers(cb: (rows: DocumentData[]) => void): void {
    this.track(onSnapshot(collection(this.db, 'players'), snap => cb(this.map(snap))));
  }

  listenEvents(cb: (rows: DocumentData[]) => void): void {
    this.track(onSnapshot(collection(this.db, 'events'), snap => cb(this.map(snap))));
  }

  listenIslands(cb: (rows: DocumentData[]) => void): void {
    this.track(onSnapshot(collection(this.db, 'islands'), snap => cb(this.map(snap))));
  }

  async sendCommand(payload: Record<string, unknown>): Promise<void> {
    const nonce = crypto.randomUUID();
    await addDoc(collection(this.db, 'commands'), { ...payload, nonce, createdAt: Date.now() });
  }

  dispose(): void {
    this.unsubs.forEach(u => u());
    this.unsubs = [];
  }

  private track(unsub: Unsub): void {
    this.unsubs.push(unsub);
  }

  private map(snap: QuerySnapshot<DocumentData>): DocumentData[] {
    return snap.docs.map(d => ({ id: d.id, ...d.data() }));
  }
}
EOF2

mkdir -p functions/src infra/.github/workflows tools
cat > functions/package.json <<'EOF2'
{
  "name": "functions",
  "type": "module",
  "scripts": {
    "build": "tsc",
    "deploy": "npm run build && firebase deploy --only functions --config ../infra/firebase.json --project YOUR_PROJECT_ID"
  },
  "dependencies": {
    "firebase-admin": "^11.11.0",
    "firebase-functions": "^4.9.0",
    "seedrandom": "^3.0.5"
  },
  "devDependencies": {
    "typescript": "^5.8.3"
  }
}
EOF2

cat > functions/src/index.ts <<'EOF2'
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import seedrandom from 'seedrandom';

admin.initializeApp();
const db = admin.firestore();

export const tick = functions.pubsub.schedule('every 1 minutes').onRun(async () => {
  const tickNumber = Math.floor(Date.now() / 60000);
  await db.runTransaction(async tx => {
    const markerRef = db.collection('tickMarkers').doc(String(tickNumber));
    const markerSnap = await tx.get(markerRef);
    if (markerSnap.exists) {
      return;
    }
    tx.create(markerRef, { createdAt: admin.firestore.FieldValue.serverTimestamp() });

    const islandsSnap = await tx.get(db.collection('islands'));
    islandsSnap.docs.forEach(doc => {
      const data = doc.data() as { ownerId?: string; resources?: number };
      const ownerId = data.ownerId ?? '0';
      const rng = seedrandom(`${tickNumber}:${ownerId}:${doc.id}`);
      const gain = Math.floor(rng() * 10);
      tx.update(doc.ref, { resources: (data.resources ?? 0) + gain, tick: tickNumber });
    });
  });
});
EOF2

cat > infra/.github/workflows/ci.yml <<'EOF2'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: android-actions/setup-android@v3
        with:
          api-level: 34
          cmdline-tools: latest
      - run: npm ci
      - run: npm run build
      - run: npx cap sync android --config app/capacitor.config.ts
      - run: |
          cd app/android
          ./gradlew --no-daemon :app:assembleRelease
          cd ../../
      - run: node tools/sign-android.mjs app/android/app/build/outputs/apk/release/app-release-unsigned.apk app-release.apk
      - uses: actions/upload-artifact@v4
        with:
          name: app-release
          path: app-release.apk
EOF2

cat > tools/sign-android.mjs <<'EOF2'
import { spawnSync } from 'node:child_process';

const [, , input, output] = process.argv;
if (!input || !output) {
  console.error('Usage: node tools/sign-android.mjs <input.apk> <output.apk>');
  process.exit(1);
}

const keystore = process.env.ANDROID_KEYSTORE || `${process.env.HOME}/.android/debug.keystore`;
const alias = process.env.ANDROID_KEY_ALIAS || 'androiddebugkey';
const storepass = process.env.ANDROID_KEYSTORE_PASS || 'android';
const keypass = process.env.ANDROID_KEY_PASS || 'android';

const res = spawnSync('apksigner', [
  'sign',
  '--ks', keystore,
  '--ks-key-alias', alias,
  '--ks-pass', `pass:${storepass}`,
  '--key-pass', `pass:${keypass}`,
  '--out', output,
  input
], { stdio: 'inherit' });

process.exit(res.status ?? 0);
EOF2

cat > infra/firebase.json <<'EOF2'
{
  "functions": {}
}
EOF2

node -e "const fs=require('fs');const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));pkg.dependencies=pkg.dependencies||{};if(!pkg.dependencies.firebase){pkg.dependencies.firebase='^10.12.2';}fs.writeFileSync('package.json',JSON.stringify(pkg,null,2));"

if npm run | grep -q '^ *build'; then
  npm run build
fi

cat > capacitor.config.ts <<'EOF2'
import config from './app/capacitor.config';
export default config;
EOF2
npx cap sync android
rm capacitor.config.ts

if command -v sdkmanager >/dev/null 2>&1; then
  yes | sdkmanager --licenses >/dev/null
fi

./gradlew --no-daemon :app:clean :app:assembleDebug

APK_PATH="$APP_ANDROID_DIR/build/outputs/apk/debug/app-debug.apk"
echo "APK at $APK_PATH"

read -r -p "Commit changes? [y/N] " ans
if [ "$ans" = "y" ]; then
  git add .
  git commit -m 'Finalize project'
fi

import { execFileSync } from 'node:child_process';

const [,, inApk, outApk] = process.argv;
if (!inApk || !outApk) {
  console.error('Usage: node sign-android.mjs <in-apk> <out-apk>');
  process.exit(1);
}

const ks = process.env.ANDROID_KEYSTORE || `${process.env.HOME}/.android/debug.keystore`;
const alias = process.env.ANDROID_KEYSTORE_ALIAS || 'androiddebugkey';
const pass = process.env.ANDROID_KEYSTORE_PASS || 'android';

execFileSync('apksigner', [
  'sign',
  '--ks', ks,
  '--ks-key-alias', alias,
  '--ks-pass', `pass:${pass}`,
  '--key-pass', `pass:${pass}`,
  '--out', outApk,
  inApk
], { stdio: 'inherit' });

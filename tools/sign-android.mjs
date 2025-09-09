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

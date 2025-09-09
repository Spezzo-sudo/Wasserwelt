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

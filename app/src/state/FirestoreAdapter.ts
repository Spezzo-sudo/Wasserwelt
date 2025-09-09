import { initializeApp } from 'firebase/app';
import { getAuth, signInAnonymously } from 'firebase/auth';
import { getFirestore, collection, onSnapshot, addDoc, QuerySnapshot, DocumentData } from 'firebase/firestore';

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
    this.track(onSnapshot(collection(this.db, 'players'), s => cb(this.map(s))));
  }
  listenEvents(cb: (rows: DocumentData[]) => void): void {
    this.track(onSnapshot(collection(this.db, 'events'), s => cb(this.map(s))));
  }
  listenIslands(cb: (rows: DocumentData[]) => void): void {
    this.track(onSnapshot(collection(this.db, 'islands'), s => cb(this.map(s))));
  }

  async sendCommand(payload: Record<string, unknown>): Promise<void> {
    const nonce = crypto.randomUUID();
    await addDoc(collection(this.db, 'commands'), { ...payload, nonce, createdAt: Date.now() });
  }

  dispose(): void {
    this.unsubs.forEach(u => u());
    this.unsubs = [];
  }

  private track(u: Unsub): void { this.unsubs.push(u); }
  private map(s: QuerySnapshot<DocumentData>): DocumentData[] {
    return s.docs.map(d => ({ id: d.id, ...d.data() }));
  }
}

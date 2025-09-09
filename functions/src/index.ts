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
    if (markerSnap.exists) return;

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

import { useEffect, useRef } from 'react';
import { startGame } from './game/main';

export default function App() {
  const rootRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!rootRef.current) return;
    const game = startGame(rootRef.current);
    return () => game.destroy(true);
  }, []);

  return (
    <div
      ref={rootRef}
      style={{ width: '100vw', height: '100vh', overflow: 'hidden' }}
    />
  );
}

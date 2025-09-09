import Phaser from 'phaser';

export function startGame(parent: HTMLElement) {
  const game = new Phaser.Game({
    type: Phaser.AUTO,
    parent,
    backgroundColor: '#0b1220',
    scale: { mode: Phaser.Scale.RESIZE, autoCenter: Phaser.Scale.NO_CENTER },
    physics: { default: 'arcade' },
    scene: {
      create() {
        const w = this.scale.width;
        const h = this.scale.height;

        this.add.text(16, 16, 'Neo-Hydraulik – Hello Phaser', {
          fontFamily: 'system-ui, sans-serif',
          fontSize: '20px',
          color: '#e2f0ff'
        });

        const g = this.add.graphics();
        let r = 10, dir = 1;
        this.time.addEvent({
          delay: 16,
          loop: true,
          callback: () => {
            r += dir * 0.8;
            if (r > 40 || r < 10) dir *= -1;
            g.clear();
            g.lineStyle(2, 0x69d2ff, 1);
            g.strokeCircle(w/2, h/2, r);
          }
        });
      }
    }
  });
  return game;
}

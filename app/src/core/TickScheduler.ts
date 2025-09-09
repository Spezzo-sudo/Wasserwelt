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

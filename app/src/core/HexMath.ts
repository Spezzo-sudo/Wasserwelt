export interface Axial { q: number; r: number; }
export interface Cube { x: number; y: number; z: number; }

export const directions: Axial[] = [
  { q: 1, r: 0 }, { q: 1, r: -1 }, { q: 0, r: -1 },
  { q: -1, r: 0 }, { q: -1, r: 1 }, { q: 0, r: 1 }
];

export function axialToCube({ q, r }: Axial): Cube {
  const x = q, z = r, y = -x - z;
  return { x, y, z };
}
export function cubeToAxial({ x, z }: Cube): Axial { return { q: x, r: z }; }

export function neighbors(a: Axial): Axial[] {
  return directions.map(d => ({ q: a.q + d.q, r: a.r + d.r }));
}

export function distance(a: Axial, b: Axial): number {
  const ac = axialToCube(a), bc = axialToCube(b);
  return Math.max(Math.abs(ac.x - bc.x), Math.abs(ac.y - bc.y), Math.abs(ac.z - bc.z));
}

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const cubeLerp = (a: Cube, b: Cube, t: number): Cube =>
  ({ x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t), z: lerp(a.z, b.z, t) });

export function line(a: Axial, b: Axial): Axial[] {
  const N = Math.max(1, distance(a, b));
  const ac = axialToCube(a), bc = axialToCube(b);
  const out: Axial[] = [];
  for (let i = 0; i <= N; i++) {
    const p = cubeLerp(ac, bc, i / N);
    out.push(cubeToAxial({ x: Math.round(p.x), y: Math.round(p.y), z: Math.round(p.z) }));
  }
  return out;
}

export function ring(center: Axial, radius: number): Axial[] {
  if (radius === 0) return [center];
  const out: Axial[] = [];
  let c = axialToCube({ q: center.q + directions[4].q * radius, r: center.r + directions[4].r * radius });
  for (let i = 0; i < 6; i++) {
    for (let j = 0; j < radius; j++) {
      out.push(cubeToAxial(c));
      const d = axialToCube(directions[i]);
      c = { x: c.x + d.x, y: c.y + d.y, z: c.z + d.z };
    }
  }
  return out;
}

type Node = { pos: Axial; g: number; f: number; parent?: Node };
export function aStar(start: Axial, goal: Axial, passable: (h: Axial) => boolean): Axial[] {
  const key = (p: Axial) => `${p.q},${p.r}`;
  const open: Node[] = [{ pos: start, g: 0, f: distance(start, goal) }];
  const closed = new Set<string>();

  while (open.length) {
    open.sort((a, b) => a.f - b.f);
    const current = open.shift()!;
    if (current.pos.q === goal.q && current.pos.r === goal.r) {
      const path: Axial[] = [];
      for (let n: Node | undefined = current; n; n = n.parent) path.push(n.pos);
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
      existing ? (existing.g = g, existing.f = g + h, existing.parent = current) : open.push(node);
    }
  }
  return [];
}

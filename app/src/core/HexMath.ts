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

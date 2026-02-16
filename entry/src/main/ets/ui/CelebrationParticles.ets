import { DesignTokens } from '../model/DesignTokens';

class ParticleState {
  id: string;
  startX: number;
  startY: number;
  endX: number;
  endY: number;
  size: number;
  color: ResourceColor;
  delayMs: number;

  constructor(
    id: string,
    startX: number,
    startY: number,
    endX: number,
    endY: number,
    size: number,
    color: ResourceColor,
    delayMs: number
  ) {
    this.id = id;
    this.startX = startX;
    this.startY = startY;
    this.endX = endX;
    this.endY = endY;
    this.size = size;
    this.color = color;
    this.delayMs = delayMs;
  }
}

@Component
export struct CelebrationParticles {
  seed: number = 0;

  @State private particles: ParticleState[] = [];
  @State private progress: number = 0;
  @State private alpha: number = 1;

  aboutToAppear(): void {
    this.play();
  }

  private play(): void {
    this.particles = this.buildParticles(this.seed);
    this.progress = 0;
    this.alpha = 1;

    const startDelay = 10;
    setTimeout(() => {
      animateTo({ duration: 900, curve: Curve.EaseOut }, () => {
        this.progress = 1;
      });
    }, startDelay);

    setTimeout(() => {
      animateTo({ duration: 350, curve: Curve.EaseIn }, () => {
        this.alpha = 0;
      });
    }, 950);
  }

  private buildParticles(seed: number): ParticleState[] {
    const colors: ResourceColor[] = [
      DesignTokens.Colors.SUCCESS,
      DesignTokens.Colors.SUCCESS_LIGHT,
      '#A7F3D0',
      '#34D399'
    ];

    const out: ParticleState[] = [];
    const count = 28;
    const centerX = 180;
    const startY = 120;

    let i = 0;
    while (i < count) {
      const id = `p_${seed}_${i}`;
      const angle = (Math.random() * Math.PI * 2);
      const radius = 120 + Math.random() * 120;
      const endX = centerX + Math.cos(angle) * radius;
      const endY = startY + Math.sin(angle) * radius + 280;
      const size = 6 + Math.floor(Math.random() * 8);
      const color = colors[i % colors.length];
      const delay = Math.floor(Math.random() * 120);
      out.push(new ParticleState(id, centerX, startY, endX, endY, size, color, delay));
      i++;
    }

    return out;
  }

  private getParticleX(p: ParticleState): number {
    return p.startX + (p.endX - p.startX) * this.progress;
  }

  private getParticleY(p: ParticleState): number {
    return p.startY + (p.endY - p.startY) * this.progress;
  }

  build() {
    Stack() {
      ForEach(this.particles, (p: ParticleState) => {
        Circle()
          .width(p.size)
          .height(p.size)
          .fill(p.color)
          .opacity(this.alpha)
          .position({ x: this.getParticleX(p), y: this.getParticleY(p) })
      }, (p: ParticleState) => p.id)
    }
    .width('100%')
    .height('100%')
    .opacity(this.alpha)
  }
}


import Curves from '@ohos.curves';

export interface SpringPreset {
  stiffness: number;
  damping: number;
  mass: number;
  velocity?: number;
}

export class SpringPresets {
  static readonly GENTLE: SpringPreset = {
    stiffness: 150,
    damping: 14,
    mass: 1
  };

  static readonly BOUNCY: SpringPreset = {
    stiffness: 180,
    damping: 10,
    mass: 1
  };

  static readonly ELASTIC: SpringPreset = {
    stiffness: 200,
    damping: 8,
    mass: 1
  };

  static readonly SNAPPY: SpringPreset = {
    stiffness: 300,
    damping: 18,
    mass: 1
  };

  static readonly STIFF: SpringPreset = {
    stiffness: 400,
    damping: 22,
    mass: 1
  };

  static readonly SOFT: SpringPreset = {
    stiffness: 120,
    damping: 16,
    mass: 1
  };

  static readonly PLAYFUL: SpringPreset = {
    stiffness: 250,
    damping: 12,
    mass: 1
  };

  static readonly RESPONSIVE: SpringPreset = {
    stiffness: 280,
    damping: 16,
    mass: 1
  };

  static readonly CUSTOM = (
    stiffness: number,
    damping: number,
    mass: number = 1
  ): SpringPreset => ({
    stiffness,
    damping,
    mass
  });
}

export class SpringCurves {
  static gentle(): ICurve {
    return Curves.springMotion(
      SpringPresets.GENTLE.stiffness,
      SpringPresets.GENTLE.damping,
      SpringPresets.GENTLE.mass
    );
  }

  static bouncy(): ICurve {
    return Curves.springMotion(
      SpringPresets.BOUNCY.stiffness,
      SpringPresets.BOUNCY.damping,
      SpringPresets.BOUNCY.mass
    );
  }

  static elastic(): ICurve {
    return Curves.springMotion(
      SpringPresets.ELASTIC.stiffness,
      SpringPresets.ELASTIC.damping,
      SpringPresets.ELASTIC.mass
    );
  }

  static snappy(): ICurve {
    return Curves.springMotion(
      SpringPresets.SNAPPY.stiffness,
      SpringPresets.SNAPPY.damping,
      SpringPresets.SNAPPY.mass
    );
  }

  static stiff(): ICurve {
    return Curves.springMotion(
      SpringPresets.STIFF.stiffness,
      SpringPresets.STIFF.damping,
      SpringPresets.STIFF.mass
    );
  }

  static soft(): ICurve {
    return Curves.springMotion(
      SpringPresets.SOFT.stiffness,
      SpringPresets.SOFT.damping,
      SpringPresets.SOFT.mass
    );
  }

  static playful(): ICurve {
    return Curves.springMotion(
      SpringPresets.PLAYFUL.stiffness,
      SpringPresets.PLAYFUL.damping,
      SpringPresets.PLAYFUL.mass
    );
  }

  static responsive(): ICurve {
    return Curves.springMotion(
      SpringPresets.RESPONSIVE.stiffness,
      SpringPresets.RESPONSIVE.damping,
      SpringPresets.RESPONSIVE.mass
    );
  }

  static custom(stiffness: number, damping: number, mass: number = 1): ICurve {
    return Curves.springMotion(stiffness, damping, mass);
  }

  static fromPreset(preset: SpringPreset): ICurve {
    return Curves.springMotion(preset.stiffness, preset.damping, preset.mass);
  }
}

export interface SpringAnimationOptions {
  duration?: number;
  delay?: number;
  onFinish?: () => void;
}

export class SpringAnimator {
  static animate(
    preset: SpringPreset,
    options: SpringAnimationOptions,
    update: () => void
  ): void {
    const curve = SpringCurves.fromPreset(preset);
    animateTo({
      duration: options.duration ?? 400,
      curve: curve,
      delay: options.delay ?? 0,
      onFinish: options.onFinish
    }, update);
  }

  static animateBouncy(options: SpringAnimationOptions, update: () => void): void {
    SpringAnimator.animate(SpringPresets.BOUNCY, options, update);
  }

  static animateElastic(options: SpringAnimationOptions, update: () => void): void {
    SpringAnimator.animate(SpringPresets.ELASTIC, options, update);
  }

  static animateGentle(options: SpringAnimationOptions, update: () => void): void {
    SpringAnimator.animate(SpringPresets.GENTLE, options, update);
  }

  static animateSnappy(options: SpringAnimationOptions, update: () => void): void {
    SpringAnimator.animate(SpringPresets.SNAPPY, options, update);
  }

  static animateSoft(options: SpringAnimationOptions, update: () => void): void {
    SpringAnimator.animate(SpringPresets.SOFT, options, update);
  }

  static animatePlayful(options: SpringAnimationOptions, update: () => void): void {
    SpringAnimator.animate(SpringPresets.PLAYFUL, options, update);
  }

  static animateResponsive(options: SpringAnimationOptions, update: () => void): void {
    SpringAnimator.animate(SpringPresets.RESPONSIVE, options, update);
  }
}

export class SpringPhysics {
  static calculateDuration(preset: SpringPreset): number {
    const { stiffness, damping, mass } = preset;
    const omega = Math.sqrt(stiffness / mass);
    const zeta = damping / (2 * Math.sqrt(stiffness * mass));

    if (zeta < 1) {
      const dampedOmega = omega * Math.sqrt(1 - zeta * zeta);
      return Math.ceil((4 / (zeta * omega)) * 1000);
    } else {
      return Math.ceil((4 / omega) * 1000);
    }
  }

  static isUnderdamped(preset: SpringPreset): boolean {
    const { stiffness, damping, mass } = preset;
    const zeta = damping / (2 * Math.sqrt(stiffness * mass));
    return zeta < 1;
  }

  static isCriticallyDamped(preset: SpringPreset): boolean {
    const { stiffness, damping, mass } = preset;
    const zeta = damping / (2 * Math.sqrt(stiffness * mass));
    return Math.abs(zeta - 1) < 0.01;
  }

  static isOverdamped(preset: SpringPreset): boolean {
    const { stiffness, damping, mass } = preset;
    const zeta = damping / (2 * Math.sqrt(stiffness * mass));
    return zeta > 1;
  }
}

@Component
export struct SpringScaleEffect {
  @Prop scaleOnPress: number = 0.96;
  @Prop preset: SpringPreset = SpringPresets.BOUNCY;
  @State private currentScale: number = 1;
  private onPress?: () => void;
  private onRelease?: () => void;

  triggerPress(): void {
    SpringAnimator.animate(this.preset, { duration: 100 }, () => {
      this.currentScale = this.scaleOnPress;
    });
    if (this.onPress) {
      this.onPress();
    }
  }

  triggerRelease(): void {
    SpringAnimator.animate(this.preset, { duration: 400 }, () => {
      this.currentScale = 1;
    });
    if (this.onRelease) {
      this.onRelease();
    }
  }

  build() {
    Column()
      .scale({ x: this.currentScale, y: this.currentScale })
  }
}

@Component
export struct SpringBounceEffect {
  @Prop bounceHeight: number = 8;
  @Prop preset: SpringPreset = SpringPresets.ELASTIC;
  @State private offsetY: number = 0;
  @State private isAnimating: boolean = false;

  trigger(): void {
    if (this.isAnimating) {
      return;
    }
    this.isAnimating = true;

    SpringAnimator.animate(this.preset, {
      duration: 200,
      onFinish: () => {
        SpringAnimator.animate(this.preset, { duration: 400 }, () => {
          this.offsetY = 0;
          this.isAnimating = false;
        });
      }
    }, () => {
      this.offsetY = -this.bounceHeight;
    });
  }

  build() {
    Column()
      .translate({ y: this.offsetY })
  }
}

@Component
export struct SpringPulseEffect {
  @Prop pulseScale: number = 1.05;
  @Prop preset: SpringPreset = SpringPresets.PLAYFUL;
  @State private currentScale: number = 1;

  trigger(): void {
    SpringAnimator.animate(this.preset, {
      duration: 150,
      onFinish: () => {
        SpringAnimator.animate(this.preset, { duration: 400 }, () => {
          this.currentScale = 1;
        });
      }
    }, () => {
      this.currentScale = this.pulseScale;
    });
  }

  build() {
    Column()
      .scale({ x: this.currentScale, y: this.currentScale })
  }
}

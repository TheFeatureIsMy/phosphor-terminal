'use client';

import React, { useState, useEffect, useRef, useCallback, type FormEvent } from 'react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// ---------------------------------------------------------------------------
// Particle Background — lightweight canvas animation
// ---------------------------------------------------------------------------

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  opacity: number;
  color: string;
}

function ParticleCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animId: number;
    const particles: Particle[] = [];
    const PARTICLE_COUNT = 60;
    const COLORS = ['#00ff9d', '#00c2ff', '#a855f7'];

    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    };
    resize();
    window.addEventListener('resize', resize);

    // Seed particles
    for (let i = 0; i < PARTICLE_COUNT; i++) {
      particles.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        vx: (Math.random() - 0.5) * 0.3,
        vy: (Math.random() - 0.5) * 0.3,
        radius: Math.random() * 1.5 + 0.5,
        opacity: Math.random() * 0.4 + 0.1,
        color: COLORS[Math.floor(Math.random() * COLORS.length)],
      });
    }

    const draw = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      for (const p of particles) {
        p.x += p.vx;
        p.y += p.vy;

        if (p.x < 0) p.x = canvas.width;
        if (p.x > canvas.width) p.x = 0;
        if (p.y < 0) p.y = canvas.height;
        if (p.y > canvas.height) p.y = 0;

        ctx.beginPath();
        ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.globalAlpha = p.opacity;
        ctx.fill();
      }

      ctx.globalAlpha = 1;
      animId = requestAnimationFrame(draw);
    };

    draw();

    return () => {
      cancelAnimationFrame(animId);
      window.removeEventListener('resize', resize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="pointer-events-none fixed inset-0 z-0"
      aria-hidden="true"
    />
  );
}

// ---------------------------------------------------------------------------
// Background Overlays — mesh gradient + grid + noise
// ---------------------------------------------------------------------------

function BackgroundOverlays() {
  return (
    <>
      {/* Mesh gradient */}
      <div
        className="pointer-events-none fixed inset-0 z-0"
        style={{
          background: [
            'radial-gradient(ellipse at 20% 0%, rgba(0,255,157,0.06) 0%, transparent 60%)',
            'radial-gradient(ellipse at 80% 100%, rgba(255,184,0,0.04) 0%, transparent 60%)',
          ].join(', '),
        }}
      />
      {/* Grid overlay */}
      <div
        className="pointer-events-none fixed inset-0 z-0"
        style={{
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px)',
          backgroundSize: '60px 60px',
        }}
      />
    </>
  );
}

// ---------------------------------------------------------------------------
// SpotlightCard — cursor-following glow (no tilt)
// ---------------------------------------------------------------------------

interface SpotlightCardProps {
  children: React.ReactNode;
  className?: string;
  spotlightColor?: string;
}

function SpotlightCard({
  children,
  className,
  spotlightColor = 'rgba(0,255,157,0.10)',
}: SpotlightCardProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [isHovered, setIsHovered] = useState(false);

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!ref.current) return;
    const rect = ref.current.getBoundingClientRect();
    setPosition({ x: e.clientX - rect.left, y: e.clientY - rect.top });
  };

  return (
    <div
      ref={ref}
      className={cn(
        'relative overflow-hidden rounded-lg border border-white/[0.05] bg-[rgba(24,24,27,0.55)] backdrop-blur-[14px] backdrop-saturate-120',
        className,
      )}
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* Top edge highlight */}
      <div className="absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-primary/35 to-transparent" />
      {/* Spotlight overlay */}
      <div
        className="pointer-events-none absolute inset-0 rounded-lg transition-opacity duration-500"
        style={{
          background: `radial-gradient(circle at ${position.x}px ${position.y}px, ${spotlightColor}, transparent 60%)`,
          opacity: isHovered ? 1 : 0,
        }}
      />
      <div className="relative z-10">{children}</div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Logo — inline SVG with gradient fill
// ---------------------------------------------------------------------------

function PulseLogo() {
  return (
    <div className="flex flex-col items-center gap-3">
      {/* Icon mark */}
      <div className="flex h-12 w-12 items-center justify-center rounded-lg border border-primary/20 bg-primary/[0.08]">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          className="h-7 w-7"
          aria-hidden="true"
        >
          <defs>
            <linearGradient id="logo-grad" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#00ff9d" />
              <stop offset="100%" stopColor="#00c2ff" />
            </linearGradient>
          </defs>
          <path
            d="M3 12h4l3-8 4 16 3-8h4"
            stroke="url(#logo-grad)"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </div>
      {/* Wordmark */}
      <span
        className="bg-gradient-to-r from-primary to-info bg-clip-text font-display text-[1.75rem] font-bold leading-tight tracking-[-0.01em] text-transparent"
      >
        PulseDesk
      </span>
      <span className="font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-text-muted">
        <span className="text-primary">//</span> AI QUANT TRADING
      </span>
    </div>
  );
}

// ---------------------------------------------------------------------------
// LoginPage
// ---------------------------------------------------------------------------

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const handleSubmit = useCallback(
    (e: FormEvent<HTMLFormElement>) => {
      e.preventDefault();
      if (!email || !password) return;
      setIsLoading(true);
      // Simulate auth — replace with real API call
      setTimeout(() => setIsLoading(false), 1500);
    },
    [email, password],
  );

  return (
    <div className="relative flex min-h-dvh items-center justify-center bg-background p-4">
      {/* Background layers */}
      <BackgroundOverlays />
      <ParticleCanvas />

      {/* Card */}
      <SpotlightCard className="w-full max-w-[400px] animate-[fadeInUp_0.4s_cubic-bezier(0.4,0,0.2,1)_both] p-8 shadow-[0_1px_3px_rgba(0,0,0,0.3)]">
        <div className="flex flex-col items-center gap-6">
          {/* Logo */}
          <PulseLogo />

          {/* Divider */}
          <div className="h-px w-full bg-gradient-to-r from-transparent via-border to-transparent" />

          {/* Form */}
          <form onSubmit={handleSubmit} className="flex w-full flex-col gap-4">
            {/* Email */}
            <div className="flex flex-col gap-1.5">
              <label
                htmlFor="login-email"
                className="font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-text-muted"
              >
                <span className="text-primary">//</span> EMAIL
              </label>
              <input
                id="login-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="trader@pulsedesk.io"
                autoComplete="email"
                required
                className="h-10 w-full rounded-sm border border-white/[0.08] bg-white/[0.03] px-3 font-mono text-sm text-text-primary placeholder:text-text-muted transition-all focus:border-primary/50 focus:bg-primary/[0.03] focus:outline-none focus:shadow-[0_0_0_4px_rgba(0,255,157,0.1),0_0_15px_rgba(0,255,157,0.06)]"
              />
            </div>

            {/* Password */}
            <div className="flex flex-col gap-1.5">
              <div className="flex items-center justify-between">
                <label
                  htmlFor="login-password"
                  className="font-mono text-[10px] font-medium uppercase tracking-[0.15em] text-text-muted"
                >
                  <span className="text-primary">//</span> PASSWORD
                </label>
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="font-mono text-[10px] uppercase tracking-wider text-text-muted transition-colors hover:text-primary"
                >
                  {showPassword ? 'HIDE' : 'SHOW'}
                </button>
              </div>
              <div className="relative">
                <input
                  id="login-password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  autoComplete="current-password"
                  required
                  className="h-10 w-full rounded-sm border border-white/[0.08] bg-white/[0.03] px-3 pr-10 font-mono text-sm text-text-primary placeholder:text-text-muted transition-all focus:border-primary/50 focus:bg-primary/[0.03] focus:outline-none focus:shadow-[0_0_0_4px_rgba(0,255,157,0.1),0_0_15px_rgba(0,255,157,0.06)]"
                />
                {/* Lock icon */}
                <svg
                  className="pointer-events-none absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-text-muted"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                >
                  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                  <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                </svg>
              </div>
            </div>

            {/* Submit */}
            <button
              type="submit"
              disabled={isLoading || !email || !password}
              className="mt-2 inline-flex h-10 w-full items-center justify-center rounded-sm bg-primary px-4 font-mono text-xs font-bold uppercase tracking-[0.08em] text-background transition-all hover:bg-primary-hover hover:shadow-[0_0_20px_rgba(0,255,157,0.2)] focus-visible:outline-2 focus-visible:outline-primary/50 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoading ? (
                <svg
                  className="h-4 w-4 animate-spin"
                  viewBox="0 0 24 24"
                  fill="none"
                  aria-label="Loading"
                >
                  <circle
                    className="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    strokeWidth="4"
                  />
                  <path
                    className="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
                  />
                </svg>
              ) : (
                'SIGN IN'
              )}
            </button>
          </form>

          {/* Forgot password — ghost link */}
          <button
            type="button"
            className="inline-flex h-10 items-center justify-center rounded-sm border border-dashed border-white/[0.12] bg-transparent px-4 font-mono text-xs uppercase tracking-wider text-text-secondary transition-all hover:border-primary hover:text-primary hover:bg-primary-dim"
          >
            FORGOT PASSWORD?
          </button>

          {/* Divider */}
          <div className="h-px w-full bg-gradient-to-r from-transparent via-border to-transparent" />

          {/* Footer */}
          <p className="font-mono text-[11px] text-text-muted">
            Secured with{' '}
            <span className="text-primary">E2E encryption</span>
          </p>
        </div>
      </SpotlightCard>

      {/* Reduced-motion fallback */}
      <style>{`
        @keyframes fadeInUp {
          from { opacity: 0; transform: translateY(12px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @media (prefers-reduced-motion: reduce) {
          *, *::before, *::after {
            animation-duration: 0.01ms !important;
            animation-iteration-count: 1 !important;
            transition-duration: 0.01ms !important;
          }
        }
      `}</style>
    </div>
  );
}

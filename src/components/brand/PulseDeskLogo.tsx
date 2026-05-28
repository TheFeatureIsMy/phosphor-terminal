type PulseDeskLogoProps = {
  size?: number
  className?: string
  title?: string
}

export function PulseDeskLogo({ size = 40, className, title = 'PulseDesk' }: PulseDeskLogoProps) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 64 64"
      role="img"
      aria-label={title}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <rect x="7" y="7" width="50" height="50" rx="14" fill="url(#pd-panel)" />
      <rect x="7.75" y="7.75" width="48.5" height="48.5" rx="13.25" stroke="#8CFFB8" strokeOpacity=".22" strokeWidth="1.5" />
      <path d="M17 36h7l4-14 6.2 24 4.5-18H47" stroke="#8CFFB8" strokeWidth="3.8" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M18.5 24.5c6.7-6.9 18.2-7.8 26-2.1" stroke="#7DB7FF" strokeOpacity=".68" strokeWidth="2.2" strokeLinecap="round" />
      <path d="M18.5 47.5h27" stroke="#4DAA72" strokeOpacity=".34" strokeWidth="1.8" strokeLinecap="round" />
      <circle cx="17" cy="36" r="3.2" fill="#0A110D" stroke="#8CFFB8" strokeWidth="2.1" />
      <circle cx="47" cy="28" r="3.2" fill="#0A110D" stroke="#8CFFB8" strokeWidth="2.1" />
      <circle cx="44.5" cy="22.2" r="2.1" fill="#E8B86D" />
      <defs>
        <linearGradient id="pd-panel" x1="13" y1="8" x2="54" y2="57" gradientUnits="userSpaceOnUse">
          <stop stopColor="#15281D" />
          <stop offset=".55" stopColor="#0B130F" />
          <stop offset="1" stopColor="#070908" />
        </linearGradient>
      </defs>
    </svg>
  )
}

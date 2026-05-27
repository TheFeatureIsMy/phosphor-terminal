import { useState } from 'react'
import { Eye, EyeOff } from 'lucide-react'
import { cn } from '@/lib/utils'

interface FieldProps {
  label: string
  type?: string
  defaultValue?: string
  placeholder?: string
  value?: string
  onChange?: (v: string) => void
}

export function Field({ label, type = 'text', defaultValue, placeholder, value, onChange }: FieldProps) {
  return (
    <div>
      <label className="text-[12px] text-text-muted block mb-2">{label}</label>
      <input
        type={type}
        defaultValue={defaultValue}
        placeholder={placeholder}
        value={value}
        onChange={onChange ? e => onChange(e.target.value) : undefined}
        className="w-full px-4 py-2.5 text-[14px]"
      />
    </div>
  )
}

interface NumberFieldProps {
  label: string
  defaultValue: string
  step?: string
}

export function NumberField({ label, defaultValue, step }: NumberFieldProps) {
  return (
    <div>
      <label className="text-[12px] text-text-muted block mb-2">{label}</label>
      <input type="number" defaultValue={defaultValue} step={step} className="w-full px-4 py-2.5 text-[14px] font-tabular" />
    </div>
  )
}

interface PasswordFieldProps {
  label: string
  placeholder?: string
  value?: string
  onChange?: (v: string) => void
}

export function PasswordField({ label, placeholder, value, onChange }: PasswordFieldProps) {
  const [show, setShow] = useState(false)
  return (
    <div>
      <label className="text-[12px] text-text-muted block mb-2">{label}</label>
      <div className="relative">
        <input
          type={show ? 'text' : 'password'}
          placeholder={placeholder}
          value={value}
          onChange={onChange ? e => onChange(e.target.value) : undefined}
          className="w-full px-4 py-2.5 pr-10 text-[14px]"
        />
        <button
          type="button"
          onClick={() => setShow(!show)}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted hover:text-text-secondary transition-colors"
        >
          {show ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
        </button>
      </div>
    </div>
  )
}

interface ToggleProps {
  label: string
  defaultChecked?: boolean
  description?: string
}

export function Toggle({ label, defaultChecked, description }: ToggleProps) {
  const [active, setActive] = useState(!!defaultChecked)
  return (
    <button
      type="button"
      onClick={() => setActive(!active)}
      className="w-full flex items-center justify-between p-3.5 hover:bg-white/[0.02] transition-colors text-left"
      style={{ borderRadius: '2px' }}
    >
      <div className="min-w-0">
        <div className="text-[13px] font-mono font-medium">{label}</div>
        {description && <div className="text-[11px] font-mono mt-0.5" style={{ color: '#555' }}>{description}</div>}
      </div>
      <div className={cn('toggle shrink-0 ml-3', active && 'active')} />
    </button>
  )
}

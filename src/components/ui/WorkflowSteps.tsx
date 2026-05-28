import { ArrowRight } from 'lucide-react'

interface WorkflowStep {
  label: string
  highlight?: boolean
}

interface WorkflowStepsProps {
  steps: WorkflowStep[]
}

export function WorkflowSteps({ steps }: WorkflowStepsProps) {
  return (
    <div className="flex items-center gap-0 flex-wrap py-3">
      {steps.map((step, i) => (
        <div key={i} className="flex items-center">
          <span
            className="inline-flex items-center gap-1.5 px-3 py-2 text-[10px] font-mono font-medium whitespace-nowrap"
            style={{
              background: step.highlight ? 'rgba(140,255,184,0.06)' : 'rgba(255,255,255,0.03)',
              border: `1px solid ${step.highlight ? 'rgba(140,255,184,0.2)' : 'rgba(255,255,255,0.06)'}`,
              borderRadius: '2px',
              color: step.highlight ? '#8cffb8' : '#9aa8a0',
            }}
          >
            {step.label}
          </span>
          {i < steps.length - 1 && (
            <ArrowRight className="w-3.5 h-3.5 mx-1.5" style={{ color: '#8cffb8' }} />
          )}
        </div>
      ))}
    </div>
  )
}

import { PageHeader } from '@/components/ui/PageHeader'
import { TradesTable } from '@/components/shared/TradesTable'

export function TradesPage() {
  return (
    <div className="space-y-5">
      <PageHeader title="交易记录" />
      <TradesTable showStats />
    </div>
  )
}

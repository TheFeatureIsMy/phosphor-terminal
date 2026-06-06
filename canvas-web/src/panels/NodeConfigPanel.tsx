import { type Node } from '@xyflow/react'
import { INDICATORS, OPERATORS, TIMEFRAMES, FILTER_TYPES, SCALAR_OPERATORS, RANGE_OPERATORS } from '../constants'
import type { DSLError } from '../types'

interface Props {
  node: Node
  onUpdate: (id: string, data: Record<string, unknown>) => void
  onClose: () => void
}

export function NodeConfigPanel({ node, onUpdate, onClose }: Props) {
  const data = node.data as Record<string, unknown>
  const errors = (data.validationErrors ?? []) as DSLError[]

  const update = (patch: Record<string, unknown>) => {
    onUpdate(node.id, { ...data, ...patch })
  }

  return (
    <div className="config-panel">
      <div className="config-header">
        <span className="config-title">{titleForType(node.type ?? '')}</span>
        <button className="config-close" onClick={onClose}>✕</button>
      </div>
      <div className="config-body">
        {node.type === 'signalInput' && renderSignalInput(data, update)}
        {node.type === 'indicatorCondition' && renderCondition(data, update)}
        {node.type === 'filter' && renderFilter(data, update)}
        {node.type === 'positionSizing' && renderSizing(data, update)}
        {node.type === 'riskPolicy' && renderRisk(data, update)}
        {node.type === 'executionOutput' && renderOutput(data, update)}
      </div>
      {errors.length > 0 && (
        <div className="config-errors">
          <div className="errors-title">验证错误</div>
          {errors.map((e, i) => (
            <div key={i} className={`error-item ${e.severity}`}>
              <span className="error-code">{e.code}</span>
              <span className="error-msg">{e.message}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function titleForType(type: string): string {
  const map: Record<string, string> = {
    signalInput: '信号输入', indicatorCondition: '指标条件',
    filter: '过滤器', positionSizing: '仓位管理',
    riskPolicy: '风控策略', executionOutput: '执行输出',
  }
  return map[type] ?? type
}

function renderSignalInput(data: Record<string, unknown>, update: (p: Record<string, unknown>) => void) {
  const symbols = (data.symbols as string[]) ?? ['BTC/USDT']
  return (
    <>
      <label className="config-label">周期</label>
      <select className="config-select" value={data.timeframe as string} onChange={e => update({ timeframe: e.target.value })}>
        {TIMEFRAMES.map(t => <option key={t} value={t}>{t}</option>)}
      </select>
      <label className="config-label">标的 (逗号分隔)</label>
      <input className="config-input" value={symbols.join(', ')}
        onChange={e => update({ symbols: e.target.value.split(',').map(s => s.trim()).filter(Boolean) })} />
    </>
  )
}

function renderCondition(data: Record<string, unknown>, update: (p: Record<string, unknown>) => void) {
  const ruleType = (data.ruleType as string) ?? 'indicator_threshold'
  const op = (data.operator as string) ?? '>'
  const params = (data.params as Record<string, number>) ?? {}
  return (
    <>
      <label className="config-label">规则类型</label>
      <select className="config-select" value={ruleType}
        onChange={e => update({ ruleType: e.target.value })}>
        <option value="indicator_threshold">指标阈值</option>
        <option value="indicator_cross">指标交叉</option>
      </select>

      <label className="config-label">指标</label>
      <select className="config-select" value={data.indicator as string}
        onChange={e => update({ indicator: e.target.value })}>
        {INDICATORS.map(i => <option key={i.value} value={i.value}>{i.label}</option>)}
      </select>

      <label className="config-label">周期</label>
      <input className="config-input" type="number" value={params.period ?? 14}
        onChange={e => update({ params: { ...params, period: Number(e.target.value) } })} />

      {ruleType === 'indicator_threshold' && (
        <>
          <label className="config-label">操作符</label>
          <select className="config-select" value={op}
            onChange={e => update({ operator: e.target.value })}>
            {OPERATORS.filter(o => !['crosses_above', 'crosses_below'].includes(o.value))
              .map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>

          {SCALAR_OPERATORS.includes(op) && (
            <>
              <label className="config-label">值</label>
              <input className="config-input" type="number" value={data.value as number ?? 0}
                onChange={e => update({ value: Number(e.target.value) })} />
            </>
          )}
          {RANGE_OPERATORS.includes(op) && (
            <>
              <label className="config-label">最小值</label>
              <input className="config-input" type="number" value={data.minValue as number ?? 0}
                onChange={e => update({ minValue: Number(e.target.value) })} />
              <label className="config-label">最大值</label>
              <input className="config-input" type="number" value={data.maxValue as number ?? 100}
                onChange={e => update({ maxValue: Number(e.target.value) })} />
            </>
          )}
        </>
      )}

      {ruleType === 'indicator_cross' && (
        <>
          <label className="config-label">交叉指标</label>
          <select className="config-select" value={data.crossIndicator as string ?? 'sma'}
            onChange={e => update({ crossIndicator: e.target.value })}>
            {INDICATORS.map(i => <option key={i.value} value={i.value}>{i.label}</option>)}
          </select>
          <label className="config-label">方向</label>
          <select className="config-select" value={data.direction as string ?? 'crosses_above'}
            onChange={e => update({ direction: e.target.value })}>
            <option value="crosses_above">上穿</option>
            <option value="crosses_below">下穿</option>
          </select>
        </>
      )}
    </>
  )
}

function renderFilter(data: Record<string, unknown>, update: (p: Record<string, unknown>) => void) {
  const ruleType = (data.ruleType as string) ?? 'volume_filter'
  return (
    <>
      <label className="config-label">过滤类型</label>
      <select className="config-select" value={ruleType}
        onChange={e => update({ ruleType: e.target.value })}>
        {FILTER_TYPES.map(f => <option key={f.value} value={f.value}>{f.label}</option>)}
      </select>

      {(ruleType === 'volume_filter' || ruleType === 'volatility_filter') && (
        <>
          <label className="config-label">操作符</label>
          <select className="config-select" value={data.operator as string ?? '>'}
            onChange={e => update({ operator: e.target.value })}>
            {OPERATORS.filter(o => SCALAR_OPERATORS.includes(o.value))
              .map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>
          <label className="config-label">值</label>
          <input className="config-input" type="number" value={data.value as number ?? 0}
            onChange={e => update({ value: Number(e.target.value) })} />
        </>
      )}
      {ruleType === 'manipulation_score_filter' && (
        <>
          <label className="config-label">最大操控评分</label>
          <input className="config-input" type="number" step="0.01" min="0" max="1"
            value={data.maxScore as number ?? 0.5}
            onChange={e => update({ maxScore: Number(e.target.value) })} />
        </>
      )}
      {ruleType === 'cooldown_filter' && (
        <>
          <label className="config-label">冷却K线数</label>
          <input className="config-input" type="number" min="1"
            value={data.candles as number ?? 5}
            onChange={e => update({ candles: Number(e.target.value) })} />
        </>
      )}
      {ruleType === 'portfolio_exposure_filter' && (
        <>
          <label className="config-label">最大敞口 (%)</label>
          <input className="config-input" type="number" step="0.01" min="0" max="1"
            value={data.maxExposurePct as number ?? 0.3}
            onChange={e => update({ maxExposurePct: Number(e.target.value) })} />
        </>
      )}
      {ruleType === 'signal_confirmation' && (
        <>
          <label className="config-label">最低置信度</label>
          <input className="config-input" type="number" step="0.01" min="0" max="1"
            value={data.minConfidence as number ?? 0.7}
            onChange={e => update({ minConfidence: Number(e.target.value) })} />
        </>
      )}
    </>
  )
}

function renderSizing(data: Record<string, unknown>, update: (p: Record<string, unknown>) => void) {
  return (
    <>
      <label className="config-label">类型</label>
      <select className="config-select" value="fixed_pct" disabled>
        <option value="fixed_pct">固定百分比</option>
      </select>
      <label className="config-label">仓位比例</label>
      <input className="config-input" type="number" step="0.01" min="0.01" max="1"
        value={data.positionPct as number ?? 0.02}
        onChange={e => update({ positionPct: Number(e.target.value) })} />
    </>
  )
}

function renderRisk(data: Record<string, unknown>, update: (p: Record<string, unknown>) => void) {
  return (
    <>
      <label className="config-label">止损 (%)</label>
      <input className="config-input" type="number" step="0.01" max="-0.01"
        value={data.stoploss as number ?? -0.05}
        onChange={e => update({ stoploss: Number(e.target.value) })} />
      <label className="config-label">最大持仓数</label>
      <input className="config-input" type="number" min="1"
        value={data.maxOpenTrades as number ?? 3}
        onChange={e => update({ maxOpenTrades: Number(e.target.value) })} />
      <label className="config-label">追踪止损</label>
      <select className="config-select" value={data.trailingStop ? 'true' : 'false'}
        onChange={e => update({ trailingStop: e.target.value === 'true' })}>
        <option value="false">关闭</option>
        <option value="true">开启</option>
      </select>
    </>
  )
}

function renderOutput(data: Record<string, unknown>, update: (p: Record<string, unknown>) => void) {
  return (
    <>
      <label className="config-label">入场逻辑</label>
      <select className="config-select" value={data.entryLogic as string ?? 'AND'}
        onChange={e => update({ entryLogic: e.target.value })}>
        <option value="AND">AND (全部满足)</option>
        <option value="OR">OR (任一满足)</option>
      </select>
      <label className="config-label">出场逻辑</label>
      <select className="config-select" value={data.exitLogic as string ?? 'OR'}
        onChange={e => update({ exitLogic: e.target.value })}>
        <option value="AND">AND (全部满足)</option>
        <option value="OR">OR (任一满足)</option>
      </select>
      <div className="config-notice">Schema: 2.5 (固定)</div>
    </>
  )
}

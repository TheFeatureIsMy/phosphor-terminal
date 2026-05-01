import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AppShell } from '@/components/layout/AppShell'
import { DashboardPage } from '@/pages/DashboardPage'
import { StrategiesPage } from '@/pages/StrategiesPage'
import { StrategyCanvasPage } from '@/pages/StrategyCanvasPage'
import { BacktestPage } from '@/pages/BacktestPage'
import { TradesPage } from '@/pages/TradesPage'
import { SettingsPage } from '@/pages/SettingsPage'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5000,
      retry: 1,
    },
  },
})

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route element={<AppShell />}>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/strategies" element={<StrategiesPage />} />
            <Route path="/strategies/:id/canvas" element={<StrategyCanvasPage />} />
            <Route path="/backtest" element={<BacktestPage />} />
            <Route path="/trades" element={<TradesPage />} />
            <Route path="/settings" element={<SettingsPage />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  )
}

export default App

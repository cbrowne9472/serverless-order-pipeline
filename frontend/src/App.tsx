import { useCallback, useEffect, useRef, useState } from 'react'
import { listOrders } from './api'
import DlqMonitor from './components/DlqMonitor'
import OrderFeed from './components/OrderFeed'
import PipelineChart from './components/PipelineChart'
import PlaceOrder from './components/PlaceOrder'
import type { Order } from './types'

const POLL_INTERVAL_MS = 5000

export default function App() {
  const [orders, setOrders] = useState<Order[]>([])
  const [loading, setLoading] = useState(false)
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  const [error, setError] = useState<string | null>(null)
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)

  const fetchOrders = useCallback(async () => {
    setLoading(true)
    try {
      const data = await listOrders()
      setOrders(data)
      setLastUpdated(new Date())
      setError(null)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch orders')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchOrders()
    intervalRef.current = setInterval(fetchOrders, POLL_INTERVAL_MS)
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current)
    }
  }, [fetchOrders])

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 px-6 py-4">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-indigo-600 flex items-center justify-center">
              <span className="text-white text-xs font-bold">OP</span>
            </div>
            <div>
              <h1 className="text-sm font-semibold text-gray-900">Order Pipeline</h1>
              <p className="text-xs text-gray-400">Admin Dashboard</p>
            </div>
          </div>
          <div className="flex items-center gap-2 text-xs text-gray-500">
            <span className="px-2 py-1 bg-gray-100 rounded font-mono">us-east-1</span>
            <span className="px-2 py-1 bg-indigo-50 text-indigo-600 rounded font-medium">dev</span>
          </div>
        </div>
      </header>

      {/* Main */}
      <main className="max-w-6xl mx-auto px-6 py-8 space-y-6">
        {error && (
          <div className="bg-red-50 border border-red-200 text-red-700 text-sm px-4 py-3 rounded-lg">
            {error}
          </div>
        )}

        <PipelineChart orders={orders} />

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <PlaceOrder onOrderPlaced={fetchOrders} />
          <DlqMonitor />
        </div>

        <OrderFeed orders={orders} loading={loading} lastUpdated={lastUpdated} />
      </main>
    </div>
  )
}

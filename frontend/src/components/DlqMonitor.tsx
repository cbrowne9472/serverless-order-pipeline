import { useEffect, useState } from 'react'
import { getDlqDepths } from '../api'
import type { DlqDepth } from '../api'

const POLL_INTERVAL_MS = 30_000

function friendlyName(name: string) {
  return name
    .replace('serverless-order-pipeline-dev-', '')
    .replace('-dlq', '')
    .replace(/-/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase())
}

export default function DlqMonitor() {
  const [dlqs, setDlqs] = useState<DlqDepth[]>([])
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function fetchDepths() {
    try {
      const data = await getDlqDepths()
      setDlqs(data)
      setLastUpdated(new Date())
      setError(null)
    } catch {
      setError('Could not load DLQ data')
    }
  }

  useEffect(() => {
    fetchDepths()
    const interval = setInterval(fetchDepths, POLL_INTERVAL_MS)
    return () => clearInterval(interval)
  }, [])

  const totalDepth = dlqs.reduce((sum, d) => sum + d.depth, 0)

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide">
          DLQ Monitor
        </h2>
        <div className="flex items-center gap-2">
          {lastUpdated && (
            <span className="text-xs text-gray-400">{lastUpdated.toLocaleTimeString()}</span>
          )}
          <span
            className={`text-xs px-2 py-0.5 rounded-full font-medium ${
              totalDepth === 0 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
            }`}
          >
            {totalDepth === 0 ? 'All clear' : `${totalDepth} message${totalDepth > 1 ? 's' : ''}`}
          </span>
        </div>
      </div>

      {error && <p className="text-xs text-red-500 mb-3">{error}</p>}

      <div className="grid grid-cols-2 gap-2">
        {dlqs.map((dlq) => (
          <div
            key={dlq.name}
            className={`rounded-lg border px-3 py-2 flex items-center justify-between ${
              dlq.depth === 0
                ? 'border-green-100 bg-green-50'
                : 'border-red-200 bg-red-50'
            }`}
          >
            <span className="text-xs text-gray-600 truncate">{friendlyName(dlq.name)}</span>
            <span
              className={`text-xs font-bold ml-2 flex-shrink-0 ${
                dlq.depth === 0 ? 'text-green-600' : 'text-red-600'
              }`}
            >
              {dlq.depth}
            </span>
          </div>
        ))}
      </div>
    </div>
  )
}

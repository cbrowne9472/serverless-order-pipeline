import type { Order, OrderStatus } from '../types'

interface Props {
  orders: Order[]
  loading: boolean
  lastUpdated: Date | null
}

const STATUS_STYLES: Record<OrderStatus, string> = {
  PENDING: 'bg-slate-100 text-slate-700',
  VALIDATED: 'bg-blue-100 text-blue-700',
  VALIDATION_FAILED: 'bg-red-100 text-red-700',
  INVENTORY_RESERVED: 'bg-purple-100 text-purple-700',
  INSUFFICIENT_STOCK: 'bg-orange-100 text-orange-700',
  PAYMENT_CONFIRMED: 'bg-green-100 text-green-700',
  PAYMENT_FAILED: 'bg-red-100 text-red-700',
}

function shortId(id: string) {
  return id.slice(0, 8).toUpperCase()
}

function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString()
}

export default function OrderFeed({ orders, loading, lastUpdated }: Props) {
  return (
    <div className="bg-white rounded-xl border border-gray-200">
      <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
        <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide">
          Live Order Feed
        </h2>
        <div className="flex items-center gap-3">
          {loading && (
            <span className="text-xs text-gray-400 animate-pulse">Refreshing…</span>
          )}
          {lastUpdated && (
            <span className="text-xs text-gray-400">
              Updated {lastUpdated.toLocaleTimeString()}
            </span>
          )}
          <span className="flex items-center gap-1 text-xs text-green-600 font-medium">
            <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse inline-block" />
            Live
          </span>
        </div>
      </div>

      {orders.length === 0 && !loading ? (
        <div className="px-6 py-12 text-center text-gray-400 text-sm">
          No orders yet — place one to see it flow through the pipeline.
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="text-xs text-gray-400 uppercase tracking-wide border-b border-gray-100">
                <th className="px-6 py-3 text-left font-medium">Order ID</th>
                <th className="px-6 py-3 text-left font-medium">Customer</th>
                <th className="px-6 py-3 text-left font-medium">Item</th>
                <th className="px-6 py-3 text-left font-medium">Qty</th>
                <th className="px-6 py-3 text-left font-medium">Status</th>
                <th className="px-6 py-3 text-left font-medium">Time</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50">
              {orders.map((order) => (
                <tr key={order.order_id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-6 py-3 font-mono text-gray-600 text-xs">
                    {shortId(order.order_id)}
                  </td>
                  <td className="px-6 py-3 text-gray-700 truncate max-w-[160px]">
                    {order.customer_email}
                  </td>
                  <td className="px-6 py-3 text-gray-600">{order.item_id}</td>
                  <td className="px-6 py-3 text-gray-600">{order.quantity}</td>
                  <td className="px-6 py-3">
                    <span
                      className={`inline-block px-2 py-1 rounded-full text-xs font-medium whitespace-nowrap ${
                        STATUS_STYLES[order.status] ?? 'bg-gray-100 text-gray-600'
                      }`}
                    >
                      {order.status.replace(/_/g, ' ')}
                    </span>
                  </td>
                  <td className="px-6 py-3 text-gray-400 text-xs whitespace-nowrap">
                    {formatTime(order.created_at)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

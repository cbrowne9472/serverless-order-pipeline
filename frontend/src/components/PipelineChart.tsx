import type { Order, OrderStatus } from '../types'

interface Props {
  orders: Order[]
}

interface Stage {
  label: string
  statuses: OrderStatus[]
  color: string
  successStatus?: OrderStatus
  failStatus?: OrderStatus
}

const STAGES: Stage[] = [
  {
    label: 'Order Intake',
    statuses: ['PENDING'],
    color: 'bg-slate-500',
  },
  {
    label: 'Validation',
    statuses: ['VALIDATED', 'VALIDATION_FAILED'],
    color: 'bg-blue-500',
    successStatus: 'VALIDATED',
    failStatus: 'VALIDATION_FAILED',
  },
  {
    label: 'Inventory',
    statuses: ['INVENTORY_RESERVED', 'INSUFFICIENT_STOCK'],
    color: 'bg-purple-500',
    successStatus: 'INVENTORY_RESERVED',
    failStatus: 'INSUFFICIENT_STOCK',
  },
  {
    label: 'Payment',
    statuses: ['PAYMENT_CONFIRMED', 'PAYMENT_FAILED'],
    color: 'bg-green-500',
    successStatus: 'PAYMENT_CONFIRMED',
    failStatus: 'PAYMENT_FAILED',
  },
]

function countAtStage(orders: Order[], statuses: OrderStatus[]): number {
  return orders.filter((o) => statuses.includes(o.status)).length
}

export default function PipelineChart({ orders }: Props) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-6">
        Pipeline Overview
      </h2>
      <div className="flex items-center gap-2">
        {STAGES.map((stage, i) => {
          const count = countAtStage(orders, stage.statuses)
          const failCount =
            stage.failStatus
              ? orders.filter((o) => o.status === stage.failStatus).length
              : 0
          const successCount =
            stage.successStatus
              ? orders.filter((o) => o.status === stage.successStatus).length
              : count

          return (
            <div key={stage.label} className="flex items-center gap-2 flex-1">
              <div className="flex-1">
                <div
                  className={`rounded-lg p-4 text-white ${stage.color} ${
                    count > 0 ? 'ring-2 ring-offset-2 ring-gray-300' : 'opacity-60'
                  }`}
                >
                  <div className="text-xs font-medium opacity-80 mb-1">{stage.label}</div>
                  <div className="text-2xl font-bold">{count}</div>
                  {stage.failStatus && failCount > 0 && (
                    <div className="text-xs mt-1 opacity-80">
                      {successCount} ok · {failCount} failed
                    </div>
                  )}
                </div>
              </div>
              {i < STAGES.length - 1 && (
                <div className="text-gray-300 text-xl font-light flex-shrink-0">→</div>
              )}
            </div>
          )
        })}
      </div>

      {/* Status breakdown */}
      <div className="mt-4 flex flex-wrap gap-2">
        {(
          [
            ['PENDING', 'bg-slate-100 text-slate-700'],
            ['VALIDATED', 'bg-blue-100 text-blue-700'],
            ['VALIDATION_FAILED', 'bg-red-100 text-red-700'],
            ['INVENTORY_RESERVED', 'bg-purple-100 text-purple-700'],
            ['INSUFFICIENT_STOCK', 'bg-orange-100 text-orange-700'],
            ['PAYMENT_CONFIRMED', 'bg-green-100 text-green-700'],
            ['PAYMENT_FAILED', 'bg-red-100 text-red-700'],
          ] as [OrderStatus, string][]
        ).map(([status, cls]) => {
          const n = orders.filter((o) => o.status === status).length
          if (n === 0) return null
          return (
            <span key={status} className={`text-xs px-2 py-1 rounded-full font-medium ${cls}`}>
              {status.replace(/_/g, ' ')}: {n}
            </span>
          )
        })}
      </div>
    </div>
  )
}

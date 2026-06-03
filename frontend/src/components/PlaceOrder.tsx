import { useState } from 'react'
import { placeOrder } from '../api'

interface Props {
  onOrderPlaced: () => void
}

const ITEMS = [
  { id: 'ITEM-001', label: 'Wireless Headphones — $99.99' },
  { id: 'ITEM-002', label: 'Mechanical Keyboard — $149.99' },
  { id: 'ITEM-003', label: 'USB-C Hub — $49.99' },
  { id: 'ITEM-004', label: 'HD Webcam — $79.99' },
  { id: 'ITEM-005', label: 'LED Desk Lamp — $59.99' },
]

export default function PlaceOrder({ onOrderPlaced }: Props) {
  const [email, setEmail] = useState('cbrowne2004@gmail.com')
  const [itemId, setItemId] = useState('ITEM-001')
  const [quantity, setQuantity] = useState(1)
  const [loading, setLoading] = useState(false)
  const [result, setResult] = useState<{ order_id: string } | null>(null)
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    setResult(null)
    try {
      const res = await placeOrder({
        customer_email: email,
        item_id: itemId,
        quantity,
        shipping_address: {
          line1: '123 Main St',
          city: 'Austin',
          state: 'TX',
          zip: '78701',
          country: 'US',
        },
      })
      setResult(res)
      onOrderPlaced()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to place order')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6">
      <h2 className="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-4">
        Place Test Order
      </h2>

      <form onSubmit={handleSubmit} className="space-y-3">
        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Customer Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full text-sm border border-gray-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            required
          />
        </div>

        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Item</label>
          <select
            value={itemId}
            onChange={(e) => setItemId(e.target.value)}
            className="w-full text-sm border border-gray-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          >
            {ITEMS.map((item) => (
              <option key={item.id} value={item.id}>
                {item.label}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-xs font-medium text-gray-600 mb-1">Quantity</label>
          <input
            type="number"
            min={1}
            max={10}
            value={quantity}
            onChange={(e) => setQuantity(Number(e.target.value))}
            className="w-full text-sm border border-gray-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white text-sm font-medium py-2 px-4 rounded-lg transition-colors"
        >
          {loading ? 'Placing order…' : 'Place Order →'}
        </button>
      </form>

      {result && (
        <div className="mt-3 bg-green-50 border border-green-200 rounded-lg px-3 py-2">
          <p className="text-xs font-medium text-green-700">Order placed!</p>
          <p className="text-xs text-green-600 font-mono mt-0.5">{result.order_id}</p>
          <p className="text-xs text-green-500 mt-1">Watch it flow through the pipeline ↓</p>
        </div>
      )}

      {error && (
        <div className="mt-3 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
          <p className="text-xs text-red-700">{error}</p>
        </div>
      )}
    </div>
  )
}

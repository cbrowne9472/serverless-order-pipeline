import type { Order, OrdersResponse } from './types'

const BASE_URL = import.meta.env.VITE_API_BASE_URL as string
const API_KEY = import.meta.env.VITE_API_KEY as string

const HEADERS: Record<string, string> = {
  'Content-Type': 'application/json',
  'x-api-key': API_KEY,
}

export async function listOrders(limit = 50): Promise<Order[]> {
  const res = await fetch(`${BASE_URL}/orders?limit=${limit}`, { headers: HEADERS })
  if (!res.ok) throw new Error(`Failed to fetch orders: ${res.status}`)
  const data: OrdersResponse = await res.json()
  return data.orders
}

export async function getOrder(orderId: string): Promise<Order> {
  const res = await fetch(`${BASE_URL}/orders/${orderId}`, { headers: HEADERS })
  if (!res.ok) throw new Error(`Failed to fetch order: ${res.status}`)
  return res.json()
}

export interface DlqDepth {
  name: string
  depth: number
}

export async function getDlqDepths(): Promise<DlqDepth[]> {
  const res = await fetch(`${BASE_URL}/metrics/dlqs`, { headers: HEADERS })
  if (!res.ok) throw new Error(`Failed to fetch DLQ depths: ${res.status}`)
  const data = await res.json()
  return data.dlqs as DlqDepth[]
}

export async function placeOrder(payload: {
  customer_email: string
  item_id: string
  quantity: number
  shipping_address: {
    line1: string
    city: string
    state: string
    zip: string
    country: string
  }
}): Promise<{ order_id: string }> {
  const res = await fetch(`${BASE_URL}/orders`, {
    method: 'POST',
    headers: HEADERS,
    body: JSON.stringify(payload),
  })
  if (!res.ok) throw new Error(`Failed to place order: ${res.status}`)
  return res.json()
}

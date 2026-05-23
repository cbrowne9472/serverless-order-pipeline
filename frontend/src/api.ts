import type { Order, OrdersResponse } from './types'

const BASE_URL = import.meta.env.VITE_API_BASE_URL as string

export async function listOrders(limit = 50): Promise<Order[]> {
  const res = await fetch(`${BASE_URL}/orders?limit=${limit}`)
  if (!res.ok) throw new Error(`Failed to fetch orders: ${res.status}`)
  const data: OrdersResponse = await res.json()
  return data.orders
}

export async function getOrder(orderId: string): Promise<Order> {
  const res = await fetch(`${BASE_URL}/orders/${orderId}`)
  if (!res.ok) throw new Error(`Failed to fetch order: ${res.status}`)
  return res.json()
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
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  if (!res.ok) throw new Error(`Failed to place order: ${res.status}`)
  return res.json()
}

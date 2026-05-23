export type OrderStatus =
  | 'PENDING'
  | 'VALIDATED'
  | 'VALIDATION_FAILED'
  | 'INVENTORY_RESERVED'
  | 'INSUFFICIENT_STOCK'
  | 'PAYMENT_CONFIRMED'
  | 'PAYMENT_FAILED'

export interface ShippingAddress {
  line1: string
  city: string
  state: string
  zip: string
  country: string
}

export interface Order {
  order_id: string
  customer_email: string
  item_id: string
  quantity: number
  status: OrderStatus
  created_at: string
  updated_at?: string
  shipping_address: ShippingAddress
  payment_intent_id?: string
  failure_reason?: string
}

export interface OrdersResponse {
  orders: Order[]
  count: number
}

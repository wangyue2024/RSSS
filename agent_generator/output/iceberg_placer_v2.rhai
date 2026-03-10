let initialized = false;
let total_to_sell = 500000;
let lot_size = 1000;
let remaining_to_sell = 0;
let last_delayed_price = 0;
let price_history = [];
let ask_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        remaining_to_sell = total_to_sell;
    }

    if !market.trading_enabled { return; }

    // Record current data for future use (5 ticks delayed)
    price_history.push(market.price);
    ask_history.push(market.ask_price_0);

    if price_history.len() > 5 {
        price_history.remove(0);
        ask_history.remove(0);
    }

    // Process fills from last tick
    let fill_cnt = my_orders.fill_count();
    for i in range(0, fill_cnt) {
        let side = my_orders.fill_side(i);
        if side == "sell" {
            let filled_qty = my_orders.fill_amount(i);
            remaining_to_sell -= filled_qty;
        }
    }

    // Use data from 5 ticks ago to make decisions
    let delayed_price = 0;
    let delayed_ask = 0;
    if price_history.len() == 5 {
        delayed_price = price_history[0];
        delayed_ask = ask_history[0];
        last_delayed_price = delayed_price;
    } else {
        delayed_price = last_delayed_price;
        delayed_ask = last_delayed_price;
    }

    // Cancel all existing orders each tick to potentially update price
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Place new iceberg order only if:
    // 1. We have shares left to sell.
    // 2. Delayed price is strictly above our average cost (no loss selling).
    // 3. There is a valid ask price to place at.
    if remaining_to_sell > 0 && delayed_price > account.avg_cost && delayed_ask > 0 {
        let order_qty = lot_size;
        if order_qty > remaining_to_sell {
            order_qty = remaining_to_sell;
        }
        orders.submit_limit_sell(delayed_ask, order_qty);
    }
}
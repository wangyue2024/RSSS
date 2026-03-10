let initialized = false;
let lot_size = 0;
let imbalance_threshold = 10_000;
let shift_amount = 50_000;
let spread = 2_000;
let order_tracker = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let cash_frac = rng.rand_int(40, 50);
        let max_cash_use = account.cash * cash_frac / 100;
        let approx_shares = max_cash_use * 1_000_000 / market.price;
        lot_size = rng.rand_int(approx_shares / 2, approx_shares);
        if lot_size < 1 {
            lot_size = 1;
        }
    }

    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;
    let orders_to_cancel = [];

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            orders_to_cancel.push(my_orders.pending_id(i));
        }
        i += 1;
    }

    i = 0;
    while i < orders_to_cancel.len() {
        orders.submit_cancel(orders_to_cancel[i]);
        i += 1;
    }

    let base_price = market.price;
    let imbalance = market.order_imbalance;
    let adjustment = 0;

    if imbalance > imbalance_threshold {
        adjustment = shift_amount;
    } else if imbalance < -imbalance_threshold {
        adjustment = -shift_amount;
    }

    let adjusted_mid = base_price + adjustment;
    let bid_price = adjusted_mid - spread;
    let ask_price = adjusted_mid + spread;

    if bid_price < 1 {
        bid_price = 1;
    }
    if ask_price < 1 {
        ask_price = 1;
    }

    let has_buy_pending = false;
    let has_sell_pending = false;
    pending_count = my_orders.pending_count();
    i = 0;
    while i < pending_count {
        let side = my_orders.pending_side(i);
        if side == 0 {
            has_buy_pending = true;
        } else {
            has_sell_pending = true;
        }
        i += 1;
    }

    let buy_amount = lot_size;
    if account.cash > bid_price * buy_amount / 1_000_000 && !has_buy_pending && buy_amount > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }

    let sell_amount = lot_size;
    if sell_amount > account.stock {
        sell_amount = account.stock;
    }
    if ask_price > account.avg_cost && !has_sell_pending && sell_amount > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}
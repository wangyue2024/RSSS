let initialized = false;
let stop_loss_threshold = 0;
let price_buffer = [];
let imbalance_buffer = [];
let tick_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = rng.rand_int(-50000, -10000);
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    let current_price = market.price;
    let current_imbalance = market.order_imbalance;

    price_buffer.push(current_price);
    imbalance_buffer.push(current_imbalance);
    tick_buffer.push(current_tick);

    if price_buffer.len() > 10 {
        price_buffer.remove(0);
        imbalance_buffer.remove(0);
        tick_buffer.remove(0);
    }

    let unrealized = account.unrealized_pnl;
    if unrealized < stop_loss_threshold && account.stock > 0 {
        let cancel_count = my_orders.pending_count();
        let j = 0;
        while j < cancel_count {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if price_buffer.len() < 5 {
        return;
    }

    let old_idx = price_buffer.len() - 5;
    let old_price = price_buffer[old_idx];
    let old_imbalance = imbalance_buffer[old_idx];

    let base_spread = 2000;
    let shift_amount = old_imbalance * 10;

    let bid_price = old_price - base_spread / 2 + shift_amount;
    let ask_price = old_price + base_spread / 2 + shift_amount;

    if bid_price <= 0 { bid_price = 1; }
    if ask_price <= bid_price { ask_price = bid_price + 100; }

    let order_size = 100;

    let has_bid = false;
    let has_ask = false;
    let pending_count2 = my_orders.pending_count();
    let k = 0;
    while k < pending_count2 {
        let side = my_orders.pending_side(k);
        if side == 0 { has_bid = true; }
        if side == 1 { has_ask = true; }
        k += 1;
    }

    if !has_bid && account.cash > bid_price * order_size / 2 {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if !has_ask && account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}
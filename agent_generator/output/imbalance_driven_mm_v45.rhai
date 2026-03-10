let initialized = false;
let panic_threshold = 0;
let fomo_threshold = 20000;
let imbalance_threshold = 500;
let price_adjust = 5000;
let base_spread = 15000;
let order_size = 100;
let recent_prices = [];
let panic_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        panic_threshold = -rng.rand_int(1000, 10000);
        imbalance_threshold = rng.rand_int(300, 800);
        price_adjust = rng.rand_int(3000, 8000);
        base_spread = rng.rand_int(10000, 25000);
        order_size = rng.rand_int(80, 150);
        initialized = true;
    }

    // Update price history for FOMO detection
    recent_prices.push(market.price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }

    // FOMO check: price jumped >2% in last 5 ticks
    if recent_prices.len() == 5 {
        let old_price = recent_prices[0];
        let price_change = (market.price - old_price) * 10000 / old_price;
        if price_change > fomo_threshold && !panic_triggered {
            let buy_amount = clamp_val(order_size * 2, 1, account.cash / market.price);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }

    // Panic check: unrealized PNL below threshold
    if account.unrealized_pnl < panic_threshold && account.stock > 0 && !panic_triggered {
        orders.submit_market_sell(account.stock);
        panic_triggered = true;
        return;
    }

    // Cancel orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    // Core MM strategy based on imbalance
    let imbalance = market.order_imbalance;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let spread_offset = (mid_price * base_spread) / (2 * 1000000);

    let bid_price = mid_price - spread_offset;
    let ask_price = mid_price + spread_offset;

    if imbalance > imbalance_threshold {
        let adjust = (mid_price * price_adjust) / 1000000;
        bid_price += adjust;
        ask_price += adjust;
    } else if imbalance < -imbalance_threshold {
        let adjust = (mid_price * price_adjust) / 1000000;
        bid_price -= adjust;
        ask_price -= adjust;
    }

    bid_price = clamp_val(bid_price, 1, 1000000000);
    ask_price = clamp_val(ask_price, 1, 1000000000);

    // Place limit orders if we have cash/stock
    let pending_buy = false;
    let pending_sell = false;
    let pcount = my_orders.pending_count();
    let j = 0;
    while j < pcount {
        if my_orders.pending_side(j) == 0 { pending_buy = true; }
        if my_orders.pending_side(j) == 1 { pending_sell = true; }
        j += 1;
    }

    if account.cash > bid_price && !pending_buy {
        let buy_amount = clamp_val(order_size, 1, account.cash / bid_price);
        orders.submit_limit_buy(bid_price, buy_amount);
    }

    if account.stock > 0 && !pending_sell {
        let sell_amount = clamp_val(order_size, 1, account.stock);
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}
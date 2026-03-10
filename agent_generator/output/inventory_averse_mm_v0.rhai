let initialized = false;
let base_spread;
let inventory_skew_factor;
let max_inventory_threshold;
let base_lot_multiplier;

fn on_tick() {
    if !initialized {
        base_spread = rng.rand_int(200, 1000);
        inventory_skew_factor = rng.rand_int(500, 2000);
        max_inventory_threshold = rng.rand_int(800, 2000);
        base_lot_multiplier = rng.rand_int(3000, 5000);
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let inv = account.stock;

    let spread_adj = inventory_skew_factor * inv / max_inventory_threshold;
    let bid_spread = base_spread + spread_adj;
    let ask_spread = base_spread - spread_adj;

    let bid_price = mid_price - bid_spread;
    let ask_price = mid_price + ask_spread;

    if bid_price <= 0 {
        bid_price = 1;
    }
    if ask_price <= 0 {
        ask_price = bid_price + 1;
    }

    let cash_for_trade = account.cash * base_lot_multiplier / 10000;
    let max_buy_shares = cash_for_trade / ask_price;
    let max_sell_shares = if account.stock > 0 { account.stock } else { 0 };

    let buy_lot = rng.rand_int(1, max_buy_shares);
    let sell_lot = if max_sell_shares > 0 { rng.rand_int(1, max_sell_shares) } else { 0 };

    if buy_lot > 0 {
        orders.submit_limit_buy(bid_price, buy_lot);
    }
    if sell_lot > 0 {
        orders.submit_limit_sell(ask_price, sell_lot);
    }
}
let initialized = false;
let base_order_size = 0;
let panic_threshold = 0;
let cooldown_ticks = 0;
let last_trade_tick = 0;
let offset_bps = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(20, 100);
        panic_threshold = -rng.rand_int(100_000_000, 500_000_000);
        cooldown_ticks = rng.rand_int(100, 500);
        offset_bps = rng.rand_int(10, 50);
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    if market.tick - last_trade_tick < cooldown_ticks {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.rsi_14 < 3000 {
        let price_offset = market.price * offset_bps / 10000;
        let limit_price = market.price - price_offset;
        if limit_price < 1 { limit_price = 1; }
        let max_shares = account.cash / limit_price;
        let buy_shares = if base_order_size > max_shares { max_shares } else { base_order_size };
        if buy_shares > 0 {
            orders.submit_limit_buy(limit_price, buy_shares);
            last_trade_tick = market.tick;
        }
    } else if market.rsi_14 > 7000 && account.stock > 0 {
        let price_offset = market.price * offset_bps / 10000;
        let limit_price = market.price + price_offset;
        let sell_shares = if base_order_size > account.stock { account.stock } else { base_order_size };
        if sell_shares > 0 {
            orders.submit_limit_sell(limit_price, sell_shares);
            last_trade_tick = market.tick;
        }
    }
}
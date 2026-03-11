let initialized = false;
let base_lot = 0;
let panic_threshold = 0;
let cooldown_ticks = 0;
let last_trade_tick = -1000;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    let base = price - remainder;
    if remainder >= 500_000 {
        base + 1_000_000
    } else {
        base
    }
}

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(20, 100);
        panic_threshold = -rng.rand_int(10_000, 50_000);
        cooldown_ticks = rng.rand_int(10, 30);
    }
    
    let current_tick = market.tick;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if current_tick - last_trade_tick < cooldown_ticks {
        return;
    }
    
    let cash_for_trade = account.cash * rng.rand_int(30, 50) / 100;
    let max_shares_by_cash = cash_for_trade / market.price;
    let buy_shares = if max_shares_by_cash < base_lot { max_shares_by_cash } else { base_lot };
    
    if buy_shares <= 0 {
        return;
    }
    
    if market.rsi_14 < 3000 && account.cash >= market.price * buy_shares {
        let discount = rng.rand_int(10000, 50000);
        let raw_price = market.price * (10000 - discount) / 10000;
        let buy_price = round_to_dollar(raw_price);
        if buy_price > 0 && buy_shares > 0 {
            orders.submit_limit_buy(buy_price, buy_shares);
            last_trade_tick = current_tick;
        }
    } else if market.rsi_14 > 7000 && account.stock > 0 {
        let sell_shares = if base_lot > account.stock { account.stock } else { base_lot };
        let premium = rng.rand_int(10000, 50000);
        let raw_price = market.price * (10000 + premium) / 10000;
        let sell_price = round_to_dollar(raw_price);
        if sell_price > 0 && sell_shares > 0 {
            orders.submit_limit_sell(sell_price, sell_shares);
            last_trade_tick = current_tick;
        }
    }
}
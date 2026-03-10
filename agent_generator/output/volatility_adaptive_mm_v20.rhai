let initialized = false;
let lot_size = 0;
let panic_threshold = 0;
let max_volatility = 0;
let base_spread = 5000;
let vol_multiplier = 2;

fn on_tick() {
    if !initialized {
        initialized = true;
        let equity_5pct = account.total_equity * 5 / 100;
        let max_shares = equity_5pct / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        panic_threshold = -rng.rand_int(1000, 10000);
        max_volatility = rng.rand_int(2000, 10000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick * 5 >= market.total_ticks {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if market.std_dev > max_volatility {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = 0;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }
    
    let spread = base_spread + market.std_dev * vol_multiplier;
    let half_spread = spread / 2;
    
    let buy_price = mid_price - half_spread;
    let sell_price = mid_price + half_spread;
    
    if buy_price > 0 && account.cash >= buy_price * lot_size && lot_size > 0 {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if sell_price > 0 && account.stock >= lot_size && lot_size > 0 {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}
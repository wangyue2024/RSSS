let initialized = false;
let lot_size = 0;
let max_std_dev_threshold = 0;
let price_offset = 0;
let max_capital_pct = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        max_capital_pct = rng.rand_int(1, 5);
        lot_size = (account.total_equity * max_capital_pct / 100) / market.price;
        if lot_size == 0 { lot_size = 1; }
        price_offset = rng.rand_int(10_000, 100_000);
        max_std_dev_threshold = market.price * 5 / 1000;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    if market.std_dev > max_std_dev_threshold {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() < 1 {
        return;
    }
    
    let prev_price = market.history_price(market.history_len() - 1);
    let price_change = market.price - prev_price;
    
    if price_change < 0 {
        let buy_price = market.price - price_offset;
        if buy_price > 0 && account.cash >= buy_price * lot_size {
            orders.submit_limit_buy(buy_price, lot_size);
        }
    } else if price_change > 0 && account.stock >= lot_size {
        let sell_price = market.price + price_offset;
        orders.submit_limit_sell(sell_price, lot_size);
    }
}
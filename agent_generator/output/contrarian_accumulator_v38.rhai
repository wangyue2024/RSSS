let initialized = false;
let last_trade_tick = 0;
let cooldown_ticks = 50;
let base_trade_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_trade_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let total_ticks = market.total_ticks;
    
    if current_tick >= total_ticks / 5 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let rsi = market.rsi_14;
    let tick_since_last = current_tick - last_trade_tick;
    
    if tick_since_last < cooldown_ticks {
        return;
    }
    
    let pending = my_orders.pending_count();
    if pending > 0 {
        return;
    }
    
    if rsi < 3000 {
        let buy_size = base_trade_size;
        let cash_needed = market.ask_price_0 * buy_size;
        if account.cash >= cash_needed && buy_size > 0 {
            let price_offset = rng.rand_int(-20000, -5000);
            let limit_price = market.bid_price_0 + price_offset;
            if limit_price > 0 {
                orders.submit_limit_buy(limit_price, buy_size);
                last_trade_tick = current_tick;
            }
        }
    } else if rsi > 7000 && account.stock >= 20 {
        let sell_size = base_trade_size;
        if sell_size > account.stock {
            sell_size = account.stock;
        }
        if sell_size > 0 {
            let price_offset = rng.rand_int(5000, 20000);
            let limit_price = market.ask_price_0 + price_offset;
            orders.submit_limit_sell(limit_price, sell_size);
            last_trade_tick = current_tick;
        }
    }
}
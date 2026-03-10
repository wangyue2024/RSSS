let initialized = false;
let trade_active = false;
let base_trade_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_trade_amount = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let total_ticks = market.total_ticks;
    
    trade_active = current_tick < total_ticks / 5;
    
    if !trade_active {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let price = market.price;
    let ma20 = market.ma_20;
    let atr = market.atr_14;
    
    let threshold = atr * 3 / 2;
    let deviation = abs_val(price - ma20);
    
    let cancel_count = my_orders.pending_count();
    let j = 0;
    while j < cancel_count {
        let placed_tick = my_orders.pending_placed_tick(j);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
        }
        j += 1;
    }
    
    if my_orders.pending_count() > 0 {
        return;
    }
    
    if deviation > threshold {
        if price > ma20 {
            let sell_price = market.bid_price_0;
            if sell_price > 0 && account.stock >= base_trade_amount {
                orders.submit_limit_sell(sell_price, base_trade_amount);
            }
        } else {
            let buy_price = market.ask_price_0;
            let max_buy = account.cash / buy_price;
            if buy_price > 0 && max_buy >= base_trade_amount {
                orders.submit_limit_buy(buy_price, base_trade_amount);
            }
        }
    }
}
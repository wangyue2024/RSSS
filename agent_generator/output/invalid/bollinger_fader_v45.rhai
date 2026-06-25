let initialized = false;
let panic_threshold = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(50_000, 200_000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let current_price = price_history[4];
        if (current_price - old_price) * 10000 / old_price > 200 {
            let pending_count = my_orders.pending_count();
            let i = 0;
            while i < pending_count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            orders.submit_market_buy(1000);
            return;
        }
    }
    
    let current_tick = market.tick;
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
    
    let ma_20 = market.ma_20;
    let std_dev = market.std_dev;
    let lower_band = ma_20 - 2 * std_dev;
    let upper_band = ma_20 + 2 * std_dev;
    
    let has_buy = false;
    let has_sell = false;
    let pending_count_after = my_orders.pending_count();
    let j = 0;
    while j < pending_count_after {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy = true;
        } else {
            has_sell = true;
        }
        j += 1;
    }
    
    if !has_buy {
        let buy_amount = 1000;
        let cost = lower_band * buy_amount;
        if account.cash >= cost {
            orders.submit_limit_buy(lower_band, buy_amount);
        }
    }
    
    if !has_sell && account.stock >= 1000 {
        orders.submit_limit_sell(upper_band, 1000);
    }
}
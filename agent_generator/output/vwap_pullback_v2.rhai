let initialized = false;
let panic_threshold = 0;
let vwap_threshold = 0;
let last_fomo_check = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(500000, 2000000);
        vwap_threshold = rng.rand_int(50, 200);
        last_fomo_check = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        fomo_triggered = false;
        return;
    }
    
    let price = market.price;
    let vwap = market.vwap;
    let window = 5;
    
    if market.tick - last_fomo_check >= window {
        last_fomo_check = market.tick;
        if market.history_len() >= window {
            let old_price = market.history_price(window - 1);
            let change = (price - old_price) * 10000 / old_price;
            if change > 200 {
                fomo_triggered = true;
            }
        }
    }
    
    if fomo_triggered && account.cash > 1000000 {
        let buy_amount = account.cash * 500000 / price / 1000000;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }
    
    if account.stock > 0 {
        let sell_price = vwap * 998000 / 1000000;
        if price >= sell_price {
            orders.submit_limit_sell(sell_price, account.stock);
        }
    } else if account.cash > 1000000 {
        let buy_price = vwap * (1000000 - vwap_threshold * 100) / 1000000;
        if price <= buy_price {
            let buy_amount = account.cash * 500000 / price / 1000000;
            if buy_amount > 0 {
                orders.submit_limit_buy(price, buy_amount);
            }
        }
    }
}
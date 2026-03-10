let initialized = false;
let stop_loss_threshold = 0;
let vwap_threshold = 0;
let last_eval_tick = -50;
let recent_prices = [];
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        stop_loss_threshold = rng.rand_int(50_000, 200_000);
        vwap_threshold = rng.rand_int(100_000, 500_000);
    }
    
    if recent_prices.len() >= 5 {
        recent_prices.remove(0);
    }
    recent_prices.push(market.price);
    
    if account.unrealized_pnl < -stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        fomo_triggered = false;
        return;
    }
    
    if recent_prices.len() == 5 {
        let old_price = recent_prices[0];
        let change = market.price - old_price;
        let threshold = old_price * 2 / 100;
        if change > threshold && change > 0 {
            fomo_triggered = true;
            let buy_amount = (account.cash * 50 / 100) / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
    
    if market.tick - last_eval_tick < 50 && !fomo_triggered {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    last_eval_tick = market.tick;
    
    if fomo_triggered {
        fomo_triggered = false;
        return;
    }
    
    if account.stock == 0 {
        if market.price < market.vwap - vwap_threshold {
            let buy_amount = (account.cash * 50 / 100) / market.price;
            if buy_amount > 0 {
                orders.submit_limit_buy(market.price, buy_amount);
            }
        }
    } else {
        if market.price >= market.vwap {
            orders.submit_limit_sell(market.vwap, account.stock);
        }
    }
}
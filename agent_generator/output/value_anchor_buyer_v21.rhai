let initialized = false;
let fair_value = 0;
let fomo_triggered = false;
let fomo_buy_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        fomo_buy_amount = rng.rand_int(100, 500);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() >= 5 {
        let price_now = market.price;
        let price_5_ago = market.history_price(market.history_len() - 5);
        if price_5_ago > 0 && price_now > price_5_ago {
            let jump_pct = (price_now - price_5_ago) * 10000 / price_5_ago;
            if jump_pct > 200 {
                fomo_triggered = true;
            }
        }
    }
    
    if fomo_triggered {
        orders.submit_market_buy(fomo_buy_amount);
        fomo_triggered = false;
        return;
    }
    
    let current_price = market.price;
    if current_price < fair_value {
        let amount = 0;
        if current_price < fair_value * 90 / 100 {
            amount = 500;
        } else if current_price < fair_value * 95 / 100 {
            amount = 100;
        }
        
        if amount > 0 {
            orders.submit_limit_buy(current_price, amount);
        }
    }
}
let initialized = false;
let fair_value = 0;
let price_history = [];
let fomo_triggered = false;
let buy_aggressive = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        buy_aggressive = rng.rand_int(800, 1200);
    }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.total_ticks - placed_tick > 3 {
            orders.submit_cancel(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    if price_history.len() >= 6 {
        let delayed_price = price_history[price_history.len() - 6];
        
        if price_history.len() >= 7 {
            let price_now = market.price;
            let price_old = price_history[price_history.len() - 7];
            if price_old > 0 && price_now * 100 / price_old > 102 {
                fomo_triggered = true;
            }
        }
        
        if fomo_triggered {
            let cash_available = account.cash;
            let buy_amount = cash_available * 80 / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            fomo_triggered = false;
        } else {
            let buy_amount = 0;
            
            if delayed_price < fair_value * 90 / 100 {
                buy_amount = buy_aggressive;
            } else if delayed_price < fair_value * 95 / 100 {
                buy_amount = buy_aggressive * 50 / 100;
            }
            
            if buy_amount > 0 && my_orders.pending_count() == 0 {
                let limit_price = delayed_price;
                if account.cash > limit_price * buy_amount {
                    orders.submit_limit_buy(limit_price, buy_amount);
                }
            }
        }
    }
}
let initialized = false;
let buy_threshold = 0;
let sell_threshold = 0;
let last_buy_price = 0;
let hold_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_threshold = rng.rand_int(100, 300);
        sell_threshold = rng.rand_int(50, 150);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let vwap = market.vwap;
    let price = market.price;
    
    let cancel_ids = [];
    let i = 0;
    while i < my_orders.pending_count() {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= 3 {
            cancel_ids.push(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    for id in cancel_ids {
        orders.submit_cancel(id);
    }
    
    if my_orders.pending_count() > 0 {
        return;
    }
    
    if account.stock == 0 {
        let threshold_price = vwap * (10000 - buy_threshold) / 10000;
        if price < threshold_price {
            let amount = account.cash / (price + 1);
            if amount > 0 {
                let bid_price = price + 1;
                orders.submit_limit_buy(bid_price, amount);
                last_buy_price = bid_price;
                hold_ticks = 0;
            }
        }
    } else {
        hold_ticks += 1;
        
        let profit_target = last_buy_price * (10000 + sell_threshold) / 10000;
        let stop_loss = last_buy_price * (10000 - sell_threshold) / 10000;
        
        if price >= profit_target || price <= stop_loss || hold_ticks >= 10 {
            if price >= vwap {
                orders.submit_limit_sell(vwap, account.stock);
            } else {
                let ask_price = price - 1;
                if ask_price > 0 {
                    orders.submit_limit_sell(ask_price, account.stock);
                }
            }
        }
    }
}
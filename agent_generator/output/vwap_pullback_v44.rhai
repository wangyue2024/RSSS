let initialized = false;
let panic_threshold = 0;
let price_history = [];
let current_position = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(5_000, 25_000);
    }
    
    if market.tick >= market.total_ticks / 5 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if account.unrealized_pnl < -panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        current_position = 0;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    let vwap = market.vwap;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if current_position == 0 {
        let threshold_price = vwap * 995 / 1000;
        if delayed_price < threshold_price {
            let buy_amount = account.cash / delayed_price;
            if buy_amount > 0 {
                orders.submit_limit_buy(delayed_price, buy_amount);
                current_position = 1;
            }
        }
    } else if current_position > 0 {
        if delayed_price >= vwap {
            orders.submit_limit_sell(delayed_price, account.stock);
            current_position = 0;
        }
    }
}
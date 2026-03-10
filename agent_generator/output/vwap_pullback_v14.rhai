let initialized = false;
let vwap_threshold = 0;
let panic_threshold = 0;
let price_history = [];
let fomo_jump_threshold = 20000;

fn on_tick() {
    if !initialized {
        initialized = true;
        vwap_threshold = rng.rand_int(15000, 30000);
        panic_threshold = rng.rand_int(-500000, -100000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let vwap = market.vwap;
    let avg_cost = account.avg_cost;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    price_history.push(current_price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() == 5 {
        let old_price = price_history[0];
        if old_price > 0 {
            let price_change = (current_price - old_price) * 10000 / old_price;
            if price_change > fomo_jump_threshold && account.cash > 1000000 {
                let buy_amount = account.cash * 30 / 100 / current_price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }
    
    if account.stock == 0 {
        if vwap > 0 && current_price > 0 {
            let diff_percent = (vwap - current_price) * 10000 / vwap;
            if diff_percent > vwap_threshold && account.cash > current_price {
                let buy_amount = account.cash * 50 / 100 / current_price;
                let buy_price = current_price * 101 / 100;
                if buy_amount > 0 {
                    orders.submit_limit_buy(buy_price, buy_amount);
                }
            }
        }
    } else {
        if current_price > avg_cost && current_price >= vwap * 9950 / 10000 {
            let sell_price = current_price * 99 / 100;
            if sell_price > avg_cost {
                orders.submit_limit_sell(sell_price, account.stock);
            }
        }
    }
}
let initialized = false;
let last_decision_tick = 0;
let last_ma5 = 0;
let last_ma20 = 0;
let position = 0;
let fomo_prices = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_ma5 = market.ma_5;
        last_ma20 = market.ma_20;
        for i in range(0, 5) {
            fomo_prices.push(market.price);
        }
    }

    if !market.trading_enabled { return; }

    let tick = market.tick;
    
    fomo_prices.remove(0);
    fomo_prices.push(market.price);
    
    if fomo_prices.len() >= 5 {
        let old_price = fomo_prices[0];
        let new_price = fomo_prices[4];
        if old_price > 0 && new_price > 0 {
            let change_percent = (new_price - old_price) * 10000 / old_price;
            if change_percent > 200 {
                fomo_triggered = true;
                let amount_to_buy = account.cash / market.price;
                if amount_to_buy > 0 {
                    orders.submit_market_buy(amount_to_buy);
                }
                return;
            }
        }
    }
    
    if tick - last_decision_tick < 50 && !fomo_triggered { return; }
    
    last_decision_tick = tick;
    fomo_triggered = false;
    
    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;
    
    let cross_above = last_ma5 <= last_ma20 && current_ma5 > current_ma20;
    let cross_below = last_ma5 >= last_ma20 && current_ma5 < current_ma20;
    
    last_ma5 = current_ma5;
    last_ma20 = current_ma20;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if cross_above {
        if account.stock == 0 {
            let amount_to_buy = account.cash / market.price;
            if amount_to_buy > 0 {
                if market.ask_price_0 > 0 {
                    let bid_price = market.ask_price_0 + 1;
                    orders.submit_limit_buy(bid_price, amount_to_buy);
                } else {
                    orders.submit_market_buy(amount_to_buy);
                }
            }
        }
    } else if cross_below {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
}
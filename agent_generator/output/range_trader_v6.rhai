let initialized = false;
let recent_prices = [];
let position_multiplier = 100;
let fomo_triggered = false;
let morning_active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        position_multiplier = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    morning_active = market.tick < (market.total_ticks * 20 / 100);
    if !morning_active {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }
    recent_prices.push(market.price);
    
    fomo_triggered = false;
    if recent_prices.len() >= 3 {
        let old_price = recent_prices[0];
        if old_price > 0 && market.price > old_price {
            let pct_change = (market.price - old_price) * 10000 / old_price;
            if pct_change > 200 {
                fomo_triggered = true;
            }
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if fomo_triggered {
        let amount_to_buy = (account.total_equity * 50 / 100) / market.price;
        if amount_to_buy > 0 {
            orders.submit_market_buy(amount_to_buy);
        }
        return;
    }
    
    let high_20 = market.high_20;
    let low_20 = market.low_20;
    
    if high_20 <= low_20 || high_20 <= 0 || low_20 <= 0 {
        return;
    }
    
    let spread = high_20 - low_20;
    let spread_pct = spread * 10000 / ((high_20 + low_20) / 2);
    
    let base_position = position_multiplier;
    let position_size = if spread_pct < 100 {
        base_position * 2
    } else {
        base_position
    };
    
    let buy_price = low_20 + (spread * 100 / 1000);
    let sell_price = high_20 - (spread * 100 / 1000);
    
    if market.price > buy_price && account.cash > buy_price {
        let max_buy = account.cash / buy_price;
        let buy_amount = if max_buy < position_size { max_buy } else { position_size };
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    if account.stock > 0 && market.price > account.avg_cost && sell_price > account.avg_cost {
        let sell_amount = if position_size > account.stock { account.stock } else { position_size };
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}
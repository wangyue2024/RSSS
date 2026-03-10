let initialized = false;
let fomo_triggered = false;
let stop_loss_ticks = 5;
let position_size = 100;
let buy_aggression = 80;
let last_prices = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_ticks = rng.rand_int(3, 8);
        position_size = rng.rand_int(80, 150);
        buy_aggression = rng.rand_int(70, 90);
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    last_prices.push(current_price);
    if last_prices.len() > 10 {
        last_prices.remove(0);
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 {
        let stop_price = account.avg_cost - (stop_loss_ticks * 10_000);
        if current_price <= stop_price {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if last_prices.len() >= 5 {
        let old_price = last_prices[0];
        let price_change = ((current_price - old_price) * 100) / old_price;
        if price_change > 2_00 {
            fomo_triggered = true;
        }
    }
    
    if fomo_triggered {
        let max_buy = account.cash / current_price;
        let buy_amount = if position_size < max_buy { position_size } else { max_buy };
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }
    
    if current_price > market.high_20 {
        let max_buy = account.cash / current_price;
        let adjusted_size = (position_size * buy_aggression) / 100;
        let buy_amount = if adjusted_size < max_buy { adjusted_size } else { max_buy };
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
}
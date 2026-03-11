let initialized = false;
let fair_value = 0;
let lot_size = 0;
let fomo_triggered = false;
let last_prices = [];
let window_ticks = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        let equity = account.total_equity;
        if equity > 0 {
            lot_size = rng.rand_int(1, equity * 5 / 100) / 100_000;
            if lot_size < 1 { lot_size = 1; }
        } else {
            lot_size = 100;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > fair_value * 3 / 100 {
        return;
    }
    
    last_prices.push(market.price);
    if last_prices.len() > window_ticks {
        last_prices.remove(0);
    }
    
    if last_prices.len() == window_ticks {
        let oldest = last_prices[0];
        let newest = last_prices[last_prices.len() - 1];
        let change_pct = (newest - oldest) * 10000 / oldest;
        if change_pct > 200 && !fomo_triggered {
            fomo_triggered = true;
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    fomo_triggered = false;
    
    let current_price = market.price;
    
    if current_price > fair_value * 110 / 100 {
        let sell_amount = lot_size * 3;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(current_price * 109 / 100, sell_amount);
        }
    } else if current_price > fair_value * 105 / 100 {
        let sell_amount = lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(current_price * 104 / 100, sell_amount);
        }
    }
}
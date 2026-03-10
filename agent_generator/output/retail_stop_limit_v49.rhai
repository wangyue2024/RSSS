let has_entered = false;
let entry_price = 0;
let take_profit_placed = false;
let stop_loss_placed = false;
let delayed_prices = [];
let ticks_delayed = 5;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    delayed_prices.push(market.price);
    if delayed_prices.len() > ticks_delayed {
        delayed_prices.remove(0);
    }
    
    if delayed_prices.len() < ticks_delayed {
        return;
    }
    
    let old_price = delayed_prices[0];
    
    if !has_entered {
        if account.stock == 0 && rng.rand_bool(2) {
            let buy_amount = rng.rand_int(10, 100);
            orders.submit_market_buy(buy_amount);
            has_entered = true;
            entry_price = account.avg_cost;
        }
        return;
    }
    
    if account.stock == 0 {
        return;
    }
    
    let take_profit_price_raw = entry_price * 105 / 100;
    let take_profit_rounding = take_profit_price_raw % 1_000_000;
    let take_profit_price = take_profit_price_raw - take_profit_rounding;
    if take_profit_rounding >= 500_000 {
        take_profit_price += 1_000_000;
    }
    
    let current_pending = my_orders.pending_count();
    let has_pending_sell = false;
    
    let i = 0;
    while i < current_pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if !take_profit_placed && old_price > entry_price {
        if take_profit_price > entry_price {
            orders.submit_limit_sell(take_profit_price, account.stock);
            take_profit_placed = true;
        }
    }
    
    let stop_loss_trigger = entry_price * 98 / 100;
    if old_price < stop_loss_trigger && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        stop_loss_placed = true;
    }
}
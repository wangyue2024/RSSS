// Global variables persist across ticks automatically
let initialized = false;
let fair_value = 0;
let lot_size_multiplier = 1;
let last_trade_was_loss = false;
let last_trade_avg_cost = 0;
let price_history = [];
let fomo_triggered = false;
let fomo_cooldown = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        
        let risk_factor = rng.rand_int(25, 50);
        lot_size_multiplier = account.cash * risk_factor / 100;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    if fomo_cooldown > 0 {
        fomo_cooldown -= 1;
        if fomo_cooldown == 0 {
            fomo_triggered = false;
        }
    }
    
    let fomo_window = 3;
    if price_history.len() >= fomo_window {
        let old_price = price_history[price_history.len() - fomo_window];
        let price_change = (market.price - old_price) * 100 / old_price;
        
        if price_change > 2 && !fomo_triggered {
            fomo_triggered = true;
            fomo_cooldown = 20;
            
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            
            let buy_amount = account.cash * 50 / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    let current_lot_size = lot_size_multiplier;
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
    }
    
    let current_lot_cash = current_lot_size;
    if current_lot_cash > account.cash {
        current_lot_cash = account.cash;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.price < fair_value {
        let buy_amount_shares = 0;
        
        if market.price < fair_value * 90 / 100 {
            buy_amount_shares = current_lot_cash / market.price;
        } else if market.price < fair_value * 95 / 100 {
            buy_amount_shares = current_lot_cash / market.price * 10 / 100;
        }
        
        if buy_amount_shares > 0 {
            orders.submit_limit_buy(market.price, buy_amount_shares);
        }
    }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let total_shares = 0;
        let total_cost = 0;
        
        for i in 0..fill_count {
            let side = my_orders.fill_side(i);
            if side == 0 {
                let fill_amount = my_orders.fill_amount(i);
                let fill_price = my_orders.fill_price(i);
                total_shares += fill_amount;
                total_cost += fill_amount * fill_price;
            }
        }
        
        if total_shares > 0 {
            let new_avg_cost = total_cost / total_shares;
            
            if last_trade_avg_cost > 0 && market.price < last_trade_avg_cost {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
            
            last_trade_avg_cost = new_avg_cost;
        }
    }
}
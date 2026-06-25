let initialized = false;
let total_target = 100000;
let accumulated = 0;
let base_lot = 1000;
let current_multiplier = 1000;
let loss_streak = 0;
let recent_prices = [];
let volume_history = [];
let last_avg_cost = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_multiplier = base_lot;
        last_avg_cost = account.avg_cost;
    }
    
    if !market.trading_enabled { return; }
    
    let price = market.price;
    let volume = market.volume;
    
    recent_prices.push(price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }
    
    volume_history.push(volume);
    if volume_history.len() > 20 {
        volume_history.remove(0);
    }
    
    if recent_prices.len() >= 5 && !fomo_triggered {
        let price_5_ago = recent_prices[0];
        let price_change = (price - price_5_ago) * 10000 / price_5_ago;
        if price_change > 200 {
            let buy_amount = base_lot * 5;
            if account.cash > buy_amount * price {
                orders.submit_market_buy(buy_amount);
                fomo_triggered = true;
                return;
            }
        }
    }
    
    if my_orders.fill_count() > 0 {
        let last_fill_idx = my_orders.fill_count() - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        if fill_side == "buy" {
            let new_avg = (last_avg_cost * account.stock + fill_price * my_orders.fill_amount(last_fill_idx)) / (account.stock + my_orders.fill_amount(last_fill_idx));
            if new_avg < last_avg_cost {
                loss_streak += 1;
                current_multiplier = base_lot * (1 << loss_streak);
            } else {
                loss_streak = 0;
                current_multiplier = base_lot;
            }
            last_avg_cost = new_avg;
            accumulated += my_orders.fill_amount(last_fill_idx);
        } else if fill_side == "sell" {
            if fill_price < last_avg_cost {
                loss_streak += 1;
                current_multiplier = base_lot * (1 << loss_streak);
            } else {
                loss_streak = 0;
                current_multiplier = base_lot;
            }
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 && price > account.avg_cost {
        let sell_amount = current_multiplier;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        let sell_price = market.ask_price_0 - 1000;
        if sell_price > account.avg_cost {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
    
    if accumulated < total_target {
        let remaining = total_target - accumulated;
        let avg_volume = 0;
        if volume_history.len() > 0 {
            let sum = 0;
            let idx = 0;
            while idx < volume_history.len() {
                sum += volume_history[idx];
                idx += 1;
            }
            avg_volume = sum / volume_history.len();
        }
        
        let volume_ratio = 100;
        if avg_volume > 0 {
            volume_ratio = volume * 100 / avg_volume;
        }
        
        let buy_amount = current_multiplier * volume_ratio / 100;
        if buy_amount > remaining {
            buy_amount = remaining;
        }
        
        if buy_amount > 0 {
            let buy_price = market.bid_price_0 + 1000;
            if account.cash > buy_amount * buy_price {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
    
    fomo_triggered = false;
}
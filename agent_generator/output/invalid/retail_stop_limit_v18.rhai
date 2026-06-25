let position_active = false;
let entry_price = 0;
let take_profit_order_id = 0;
let take_profit_placed_tick = 0;
let stop_loss_price = 0;
let fomo_triggered = false;
let price_history = [];
let initialized = false;
let random_entry_done = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        let fill_amount = my_orders.fill_amount(i);
        if fill_side == 0 && !position_active {
            position_active = true;
            entry_price = account.avg_cost;
            take_profit_order_id = 0;
            stop_loss_price = entry_price * 98 / 100;
        } else if fill_side == 1 && position_active {
            position_active = false;
            entry_price = 0;
            take_profit_order_id = 0;
        }
        i += 1;
    }
    
    let fomo_window = 5;
    if price_history.len() >= fomo_window && !fomo_triggered && !position_active && !random_entry_done {
        let oldest_price = price_history[0];
        let current_price = market.price;
        let percent_change = (current_price - oldest_price) * 10000 / oldest_price;
        if percent_change > 200 && percent_change != 0 {
            fomo_triggered = true;
            let buy_amount = account.cash * 50 / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
    
    if !position_active && !random_entry_done && !fomo_triggered {
        if rng.rand_bool(1) {
            random_entry_done = true;
            let buy_amount = account.cash * 30 / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        if oid != take_profit_order_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if position_active {
        if take_profit_order_id == 0 {
            let tp_price = entry_price * 105 / 100;
            let sell_amount = account.stock;
            if sell_amount > 0 {
                take_profit_order_id = orders.submit_limit_sell(tp_price, sell_amount);
                take_profit_placed_tick = market.tick;
            }
        } else {
            let found = false;
            let pending_cnt = my_orders.pending_count();
            let j = 0;
            while j < pending_cnt && !found {
                if my_orders.pending_id(j) == take_profit_order_id {
                    found = true;
                }
                j += 1;
            }
            
            if !found {
                take_profit_order_id = 0;
            } else if market.tick - take_profit_placed_tick > 3 {
                orders.submit_cancel(take_profit_order_id);
                take_profit_order_id = 0;
            }
        }
        
        if market.price <= stop_loss_price {
            let sell_amount = account.stock;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                if take_profit_order_id != 0 {
                    orders.submit_cancel(take_profit_order_id);
                    take_profit_order_id = 0;
                }
            }
        }
    }
}
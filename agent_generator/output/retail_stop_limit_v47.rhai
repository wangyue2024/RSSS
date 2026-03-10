let initialized = false;
let lot_size = 0;
let random_entry_threshold = 0;
let entry_price = 0;
let take_profit_order_id = -1;
let take_profit_price = 0;
let take_profit_placed_tick = 0;
let stop_loss_triggered = false;
let trade_completed = false;
let entry_tick = -1;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let total_capital = account.total_equity;
        let risk_capital = total_capital * 5 / 100;
        lot_size = risk_capital / market.price;
        if lot_size < 1 {
            lot_size = 1;
        }
        random_entry_threshold = rng.rand_int(1, 100);
        if random_entry_threshold > 5 {
            random_entry_threshold = 5;
        }
    }
    
    if !market.trading_enabled {
        return;
    }
    
    if trade_completed {
        return;
    }
    
    let std_dev_threshold = market.price * 5 / 100;
    
    if !stop_loss_triggered && !fomo_triggered && entry_tick == -1 && market.std_dev < std_dev_threshold {
        let cancel_count = my_orders.pending_count();
        let i = 0;
        while i < cancel_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        fomo_triggered = false;
        if market.history_len() > 5 {
            let current_price = market.price;
            let price_5_ago = market.history_price(5);
            let change_pct = (current_price - price_5_ago) * 10000 / price_5_ago;
            if change_pct > 200 {
                fomo_triggered = true;
            }
        }
        
        let random_roll = rng.rand_int(0, 99);
        if fomo_triggered || random_roll < random_entry_threshold {
            orders.submit_market_buy(lot_size);
            entry_tick = market.tick;
        }
    }
    
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 0 && entry_price == 0 && entry_tick != -1 {
            entry_price = my_orders.fill_price(i);
            take_profit_price = entry_price + entry_price * 5 / 100;
            let take_profit_order = orders.submit_limit_sell(take_profit_price, lot_size);
            if take_profit_order > 0 {
                take_profit_order_id = take_profit_order;
                take_profit_placed_tick = market.tick;
            }
            entry_tick = -1;
        }
        i += 1;
    }
    
    if entry_price > 0 && !stop_loss_triggered {
        let stop_loss_price = entry_price - entry_price * 2 / 100;
        if market.price <= stop_loss_price {
            orders.submit_market_sell(lot_size);
            stop_loss_triggered = true;
            trade_completed = true;
            return;
        }
        
        let pending_count = my_orders.pending_count();
        let found_take_profit = false;
        let j = 0;
        while j < pending_count {
            let oid = my_orders.pending_id(j);
            if oid == take_profit_order_id {
                found_take_profit = true;
                if market.tick - take_profit_placed_tick > 3 {
                    orders.submit_cancel(take_profit_order_id);
                    let new_order = orders.submit_limit_sell(take_profit_price, lot_size);
                    if new_order > 0 {
                        take_profit_order_id = new_order;
                        take_profit_placed_tick = market.tick;
                    }
                }
                break;
            }
            j += 1;
        }
        
        if !found_take_profit {
            let order_history_count = my_orders.order_history_count();
            let k = 0;
            while k < order_history_count {
                let hist_id = my_orders.order_history_id(k);
                if hist_id == take_profit_order_id {
                    let status = my_orders.order_history_status(k);
                    if status == 0 {
                        trade_completed = true;
                    }
                    break;
                }
                k += 1;
            }
        }
    }
}
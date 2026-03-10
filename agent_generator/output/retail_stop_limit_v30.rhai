let price_history = [];
let delayed_price = 0;
let entry_price = 0;
let entry_filled = false;
let take_profit_id = 0;
let take_profit_placed_tick = 0;
let stop_loss_triggered = false;
let initialized = false;
let entry_order_id = 0;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_action_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() == 5 {
        delayed_price = price_history[0];
    } else {
        delayed_price = market.price;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        if oid == entry_order_id && (market.tick - last_action_tick) > 3 {
            orders.submit_cancel(oid);
            entry_order_id = 0;
        }
        if oid == take_profit_id && (market.tick - take_profit_placed_tick) > 3 {
            orders.submit_cancel(oid);
            take_profit_id = 0;
        }
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let fill_id = my_orders.fill_id(j);
        let fill_side = my_orders.fill_side(j);
        if fill_id == entry_order_id && fill_side == 0 {
            entry_price = my_orders.fill_price(j);
            entry_filled = true;
            entry_order_id = 0;
        }
        if fill_id == take_profit_id && fill_side == 1 {
            entry_filled = false;
            entry_price = 0;
            take_profit_id = 0;
            stop_loss_triggered = false;
        }
        j += 1;
    }
    
    if !entry_filled && account.stock == 0 && entry_order_id == 0 && take_profit_id == 0 {
        if rng.rand_bool(1) && price_history.len() >= 5 {
            let buy_price = delayed_price + 1;
            let buy_amount = 100;
            entry_order_id = orders.submit_limit_buy(buy_price, buy_amount);
            last_action_tick = market.tick;
        }
    }
    
    if entry_filled && account.stock > 0 && take_profit_id == 0 && !stop_loss_triggered {
        let take_profit_price = entry_price + (entry_price * 5 / 100) + 1;
        take_profit_id = orders.submit_limit_sell(take_profit_price, account.stock);
        take_profit_placed_tick = market.tick;
    }
    
    if entry_filled && account.stock > 0 && delayed_price <= (entry_price - (entry_price * 2 / 100)) && !stop_loss_triggered {
        orders.submit_market_sell(account.stock);
        stop_loss_triggered = true;
        entry_filled = false;
        entry_price = 0;
        if take_profit_id != 0 {
            orders.submit_cancel(take_profit_id);
            take_profit_id = 0;
        }
    }
}
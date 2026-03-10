let initialized = false;
let stop_loss_threshold = 0;
let price_history = [];
let std_dev_history = [];
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(5_000, 15_000);
    }
    
    if !market.trading_enabled { return; }

    price_history.push(market.price);
    std_dev_history.push(market.std_dev);
    
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    if std_dev_history.len() > 5 {
        std_dev_history.remove(0);
    }
    
    if account.unrealized_pnl < stop_loss_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let current_tick = market.tick;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            orders.submit_cancel(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    let delayed_std_dev = std_dev_history[0];
    
    if delayed_price == 0 {
        return;
    }
    
    let base_spread = 10_000;
    let volatility_adjustment = delayed_std_dev * 100 / delayed_price;
    
    let half_spread = base_spread + volatility_adjustment;
    let bid_price = delayed_price - half_spread;
    let ask_price = delayed_price + half_spread;
    
    if bid_price > 0 && account.cash > bid_price * 100 {
        orders.submit_limit_buy(bid_price, 100);
    }
    
    if ask_price > 0 && account.stock >= 100 {
        orders.submit_limit_sell(ask_price, 100);
    }
}
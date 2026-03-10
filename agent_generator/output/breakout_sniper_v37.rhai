let initialized = false;
let stop_loss_ticks = 5000;
let buy_amount = 1000;
let my_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Calculate stop-loss price if in position
    let stop_price = 0;
    if account.stock > 0 && account.avg_cost > 0 {
        stop_price = account.avg_cost - stop_loss_ticks;
    }
    
    // Breakout condition: current price > 20-period high
    let breakout = market.price > market.high_20;
    
    // Exit condition: price hits stop-loss
    let exit_signal = account.stock > 0 && market.price <= stop_price;
    
    if exit_signal {
        // Aggressive market sell to exit
        orders.submit_market_sell(account.stock);
        my_position = 0;
    } else if breakout && account.stock == 0 {
        // Calculate aggressive buy price: best ask + 1 micro (Off-by-One Pumper)
        let calc_price = market.ask_price_0;
        if calc_price > 0 {
            let buy_price = calc_price + 1;
            orders.submit_limit_buy(buy_price, buy_amount);
            my_position = buy_amount;
        }
    }
}
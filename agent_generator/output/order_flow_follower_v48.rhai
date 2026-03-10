let initialized = false;
let lot_size = 0;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_shares = (account.total_equity * 5) / (100 * market.price);
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
        
        stop_loss_threshold = -rng.rand_int(10_000, 100_000);
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let std_dev_threshold = market.price * 100 / 10000;
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    if market.buy_volume > 3 * market.sell_volume {
        if account.cash >= lot_size * market.price {
            orders.submit_limit_buy(market.price, lot_size);
        }
    }
}
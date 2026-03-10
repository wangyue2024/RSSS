let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let stop_loss_threshold = 0;
let last_decision_tick = -50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        stop_loss_threshold = rng.rand_int(-50000, -10000);
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if market.tick - last_decision_tick < 50 { return; }
    last_decision_tick = market.tick;
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.buy_volume > 3 * market.sell_volume {
        if account.stock == 0 {
            orders.submit_market_buy(current_lot);
        }
    } else if market.sell_volume > 3 * market.buy_volume && account.stock > 0 {
        let last_trade_profit = market.price - account.avg_cost;
        orders.submit_market_sell(account.stock);
        
        if last_trade_profit < 0 {
            current_lot = current_lot * 2;
            if current_lot > 10000 { current_lot = 10000; }
        } else {
            current_lot = base_lot;
        }
    }
}
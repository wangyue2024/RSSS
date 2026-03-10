let initialized = false;
let last_realized_pnl = 0;
let current_lot_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_realized_pnl = account.realized_pnl;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.realized_pnl < last_realized_pnl {
        current_lot_size = current_lot_size * 2;
    } else {
        current_lot_size = 100;
    }
    last_realized_pnl = account.realized_pnl;
    
    if market.buy_volume > 3 * market.sell_volume {
        orders.submit_market_buy(current_lot_size);
    } else if market.sell_volume > 3 * market.buy_volume {
        orders.submit_market_sell(current_lot_size);
    }
}
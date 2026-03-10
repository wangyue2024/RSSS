let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let last_trade_profit = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check for new fills to update P&L tracking
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let fill = my_orders.fill_side(0);
        let fill_price = my_orders.fill_price(0);
        
        if fill == 0 { // buy fill
            if account.stock > 0 {
                let cost_diff = fill_price - account.avg_cost;
                last_trade_profit = cost_diff * my_orders.fill_amount(0);
            }
        } else { // sell fill
            if account.stock == 0 && account.avg_cost != 0 {
                let cost_diff = account.avg_cost - fill_price;
                last_trade_profit = cost_diff * my_orders.fill_amount(0);
            }
        }
        
        // Martingale sizing
        if last_trade_profit < 0 {
            current_lot = current_lot * 2;
        } else {
            current_lot = base_lot;
        }
    }
    
    // Order flow logic
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > sell_vol * 3 {
        orders.submit_market_buy(current_lot);
    } else if sell_vol > buy_vol * 3 {
        orders.submit_market_sell(current_lot);
    }
}
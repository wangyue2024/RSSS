let initialized = false;
let panic_threshold = 0;
let lot_size = 100;
let last_trade_was_loss = false;
let has_position = false;
let cost_basis = 0;
let take_profit_order_id = -1;
let stop_order_placed = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 50_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let fill_side = my_orders.fill_side(j);
        let fill_price = my_orders.fill_price(j);
        
        if fill_side == 1 && has_position {
            if fill_price < cost_basis {
                last_trade_was_loss = true;
                lot_size = lot_size * 2;
            } else {
                last_trade_was_loss = false;
            }
            has_position = false;
            take_profit_order_id = -1;
            stop_order_placed = false;
        }
        j += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        has_position = false;
        take_profit_order_id = -1;
        stop_order_placed = false;
        return;
    }
    
    if !has_position && account.stock == 0 {
        if rng.rand_bool(5) {
            let buy_amount = lot_size;
            orders.submit_market_buy(buy_amount);
            has_position = true;
            cost_basis = account.avg_cost;
            stop_order_placed = false;
        }
        return;
    }
    
    if has_position && account.stock > 0 && !stop_order_placed {
        let stop_price = cost_basis * 98 / 100;
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
            has_position = false;
            return;
        }
        
        let raw_tp_price = cost_basis * 105 / 100;
        let rounded_tp_price = (raw_tp_price + 500_000) / 1_000_000 * 1_000_000;
        take_profit_order_id = orders.submit_limit_sell(rounded_tp_price, account.stock);
        stop_order_placed = true;
    }
}
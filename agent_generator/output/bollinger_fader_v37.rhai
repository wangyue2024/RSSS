let initialized = false;
let order_placement_ticks = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    let current_tick = market.tick;
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;
    
    let has_buy_order = false;
    let has_sell_order = false;
    
    let pending_count = my_orders.pending_count();
    let j = 0;
    while j < pending_count {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy_order = true;
        } else if side == 1 {
            has_sell_order = true;
        }
        j += 1;
    }
    
    let position = account.stock;
    let max_buy_by_cash = account.cash / lower_band;
    let buy_amount = 100;
    if buy_amount > max_buy_by_cash {
        buy_amount = max_buy_by_cash;
    }
    
    let sell_amount = 100;
    if sell_amount > position {
        sell_amount = position;
    }
    
    if !has_buy_order && buy_amount > 0 {
        orders.submit_limit_buy(lower_band, buy_amount);
    }
    
    if !has_sell_order && sell_amount > 0 {
        orders.submit_limit_sell(upper_band, sell_amount);
    }
}
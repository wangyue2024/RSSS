let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_was_loss = false;
let position_avg_cost = 0;
let order_placement_ticks = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_capital = account.total_equity * 5 / 100;
        base_lot_size = rng.rand_int(1, five_percent_capital / market.price);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    let std_dev_threshold = market.price * 200 / 10000;
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if my_orders.fill_count() > 0 {
        let last_fill_idx = my_orders.fill_count() - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        if fill_side == 0 {
            position_avg_cost = ((position_avg_cost * account.stock) + (fill_price * current_lot_size)) / (account.stock + current_lot_size);
        }
        
        let current_pnl = (market.price - position_avg_cost) * account.stock;
        if current_pnl < 0 {
            last_trade_was_loss = true;
            current_lot_size = base_lot_size * 2;
        } else {
            last_trade_was_loss = false;
            current_lot_size = base_lot_size;
        }
    }
    
    if market.buy_volume > 3 * market.sell_volume {
        if market.ask_price_0 > 0 {
            orders.submit_limit_buy(market.ask_price_0, current_lot_size);
        } else {
            orders.submit_market_buy(current_lot_size);
        }
    }
}
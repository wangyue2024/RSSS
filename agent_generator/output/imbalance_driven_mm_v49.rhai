let initialized = false;
let stop_loss_threshold = 0;
let base_spread = 0;
let imbalance_sensitivity = 0;
let lot_size_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(500_000, 2_000_000);
        base_spread = rng.rand_int(100, 500);
        imbalance_sensitivity = rng.rand_int(100, 300);
        lot_size_factor = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let max_active_tick = market.total_ticks * 20 / 100;
    if market.tick >= max_active_tick {
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(j));
            j += 1;
        }
        return;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(j));
            j += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(j));
        j += 1;
    }
    
    let base_price = market.price;
    let shift = imbalance_sensitivity * market.order_imbalance / 1000;
    
    let bid_price = base_price - base_spread / 2 + shift;
    let ask_price = base_price + base_spread / 2 + shift;
    
    if bid_price <= 0 || ask_price <= 0 { return; }
    
    let max_buy_amount = account.cash * lot_size_factor / (100 * bid_price);
    if max_buy_amount > 0 {
        orders.submit_limit_buy(bid_price, max_buy_amount);
    }
    
    let max_sell_amount = account.stock * lot_size_factor / 100;
    if max_sell_amount > 0 {
        orders.submit_limit_sell(ask_price, max_sell_amount);
    }
}
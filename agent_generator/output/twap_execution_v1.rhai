let initialized = false;
let target_position = 0;
let slice_size = 0;
let interval_ticks = 0;
let last_trade_tick = 0;
let volatility_threshold = 0;
let total_capital = 0;

fn on_tick() {
    if !initialized {
        if !market.trading_enabled { return; }
        total_capital = account.total_equity;
        let max_lot_value = total_capital * 5 / 100;
        let max_shares_by_value = max_lot_value / market.price;
        slice_size = rng.rand_int(1, max_shares_by_value);
        target_position = 50000;
        interval_ticks = rng.rand_int(5, 20);
        volatility_threshold = market.price * 5 / 100;
        last_trade_tick = market.tick;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.std_dev > volatility_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let pending_buys = 0;
    let pcount = my_orders.pending_count();
    let j = 0;
    while j < pcount {
        if my_orders.pending_side(j) == 0 {
            pending_buys += my_orders.pending_amount(j);
        }
        j += 1;
    }
    
    let current_and_pending = account.stock + pending_buys;
    let remaining_to_buy = target_position - current_and_pending;
    
    if remaining_to_buy <= 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if market.tick - last_trade_tick >= interval_ticks {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let order_amount = slice_size;
        if order_amount > remaining_to_buy {
            order_amount = remaining_to_buy;
        }
        
        if market.bid_price_0 != 0 {
            let bid_price = market.bid_price_0 + 1;
            orders.submit_limit_buy(bid_price, order_amount);
        } else {
            orders.submit_market_buy(order_amount);
        }
        
        last_trade_tick = market.tick;
    }
}
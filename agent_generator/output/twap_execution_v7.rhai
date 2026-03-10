let target_position = 50_000;
let lot_size = 0;
let initialized = false;
let trade_interval = 50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick % trade_interval != 0 { return; }
    
    if !initialized {
        let max_capital_for_trade = account.total_equity * 5 / 100;
        let max_shares = max_capital_for_trade / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 100;
        }
        initialized = true;
    }
    
    let volatility_threshold = market.price * 10 / 100;
    if market.std_dev > volatility_threshold {
        return;
    }
    
    let current_position = account.stock;
    
    if current_position < target_position {
        let to_buy = target_position - current_position;
        if to_buy > lot_size {
            to_buy = lot_size;
        }
        if to_buy > 0 {
            orders.submit_market_buy(to_buy);
        }
    } else if current_position > target_position && market.price > account.avg_cost {
        let to_sell = current_position - target_position;
        if to_sell > lot_size {
            to_sell = lot_size;
        }
        if to_sell > 0 {
            orders.submit_market_sell(to_sell);
        }
    }
}
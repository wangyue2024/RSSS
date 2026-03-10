let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let ticks_between = 10;
let next_buy_tick = 0;
let panic_threshold = 0;
let last_trade_profit = true;
let current_lot_size = 0;
let last_avg_cost = 0;
let last_position = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(1_000_000, 10_000_000);
        let cash_for_trade = account.cash * rng.rand_int(25, 50) / 100;
        if market.price > 0 {
            current_lot_size = cash_for_trade / market.price;
            if current_lot_size < 100 {
                current_lot_size = 100;
            }
        } else {
            current_lot_size = 500;
        }
        next_buy_tick = market.tick + rng.rand_int(1, 5);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let remaining = target_position - account.stock;
    if remaining <= 0 { return; }
    
    if last_position != 0 && account.stock > last_position {
        if account.avg_cost > 0 && market.price > 0 {
            if market.price < account.avg_cost {
                last_trade_profit = false;
                current_lot_size = current_lot_size * 2;
            } else {
                last_trade_profit = true;
            }
        }
    }
    last_position = account.stock;
    
    if market.tick >= next_buy_tick {
        let twap_amount = slice_size;
        if twap_amount > remaining {
            twap_amount = remaining;
        }
        if twap_amount > 0 {
            orders.submit_market_buy(twap_amount);
        }
        
        let aggressive_amount = current_lot_size;
        if aggressive_amount > remaining {
            aggressive_amount = remaining;
        }
        if aggressive_amount > 0 && rng.rand_bool(30) {
            orders.submit_market_buy(aggressive_amount);
        }
        
        next_buy_tick = market.tick + ticks_between;
    }
}
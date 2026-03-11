let initialized = false;
let base_lot = 10000;
let current_lot = 10000;
let last_trade_was_loss = false;
let loss_streak = 0;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(8000, 12000);
        current_lot = base_lot;
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
    if fill_cnt > 0 {
        let last_side = my_orders.fill_side(fill_cnt - 1);
        let last_price = my_orders.fill_price(fill_cnt - 1);
        
        if last_side == 1 {
            if last_avg_cost > 0 && last_price < last_avg_cost {
                last_trade_was_loss = true;
                loss_streak += 1;
                current_lot = base_lot * (1 << loss_streak);
            } else {
                last_trade_was_loss = false;
                loss_streak = 0;
                current_lot = base_lot;
            }
        } else if last_side == 0 {
            last_avg_cost = account.avg_cost;
        }
    }
    
    let high_20 = market.high_20;
    let low_20 = market.low_20;
    
    if high_20 <= low_20 {
        return;
    }
    
    let spread = high_20 - low_20;
    let range_narrow = spread * 100 / high_20 < 2000;
    
    let position_multiplier = if range_narrow { 3 } else { 2 };
    let adjusted_lot = current_lot * position_multiplier / 2;
    
    let offset_buy = spread * 10 / 100;
    let offset_sell = spread * 10 / 100;
    
    let buy_price = low_20 + offset_buy;
    let sell_price = high_20 - offset_sell;
    
    if buy_price < sell_price {
        if account.cash >= buy_price * adjusted_lot / 1000000 {
            orders.submit_limit_buy(buy_price, adjusted_lot);
        }
        if account.stock >= adjusted_lot {
            orders.submit_limit_sell(sell_price, adjusted_lot);
        }
    }
}
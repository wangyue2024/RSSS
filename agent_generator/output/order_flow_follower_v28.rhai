let base_lot_size = 100;
let current_lot_size = base_lot_size;
let initialized = false;
let last_position = 0;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_lot_size = base_lot_size;
        last_position = account.stock;
        last_avg_cost = account.avg_cost;
    }
    
    if !market.trading_enabled { return; }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    let current_pos = account.stock;
    let avg_cost = account.avg_cost;
    
    if current_pos != last_position {
        if last_position != 0 {
            let last_trade_result = if last_position > 0 {
                market.price - last_avg_cost
            } else {
                last_avg_cost - market.price
            };
            if last_trade_result < 0 {
                current_lot_size = current_lot_size * 2;
            } else {
                current_lot_size = base_lot_size;
            }
        }
        last_position = current_pos;
        last_avg_cost = avg_cost;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if buy_vol > 3 * sell_vol {
        if current_pos >= 0 {
            orders.submit_market_buy(current_lot_size);
        } else {
            let cover_amount = abs_val(current_pos);
            if cover_amount > 0 {
                orders.submit_market_buy(cover_amount);
            }
        }
    }
    
    if sell_vol > 3 * buy_vol {
        if current_pos <= 0 {
            orders.submit_market_sell(current_lot_size);
        } else {
            let sell_amount = abs_val(current_pos);
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        }
    }
}
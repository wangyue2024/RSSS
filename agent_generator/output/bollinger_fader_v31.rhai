let initialized = false;
let lot_size = 0;
let last_trade_loss = false;
let order_place_ticks = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_capital = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(100_000, five_percent_capital);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let std_dev_threshold = market.price * 500 / 10000;
    if market.std_dev > std_dev_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        order_place_ticks = [];
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let last_fill_side = my_orders.fill_side(last_fill_idx);
        let last_fill_price = my_orders.fill_price(last_fill_idx);
        
        if last_fill_side == 0 {
            let last_avg = account.avg_cost;
            last_trade_loss = last_fill_price > last_avg;
        } else {
            let last_avg = account.avg_cost;
            last_trade_loss = last_fill_price < last_avg;
        }
        
        if last_trade_loss {
            lot_size = lot_size * 2;
        } else {
            let five_percent_capital = account.total_equity * 5 / 100;
            lot_size = rng.rand_int(100_000, five_percent_capital);
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let order_id = my_orders.pending_id(i);
        let found_idx = -1;
        let j = 0;
        while j < order_place_ticks.len() {
            if order_place_ticks[j].id == order_id {
                found_idx = j;
                break;
            }
            j += 1;
        }
        
        if found_idx >= 0 {
            let placed_tick = order_place_ticks[found_idx].tick;
            if current_tick - placed_tick > 3 {
                orders.submit_cancel(order_id);
                order_place_ticks.remove(found_idx);
            }
        } else {
            order_place_ticks.push(#{ id: order_id, tick: current_tick });
        }
        i += 1;
    }
    
    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;
    
    let can_buy = account.cash >= lower_band * lot_size / 1_000_000;
    let can_sell = account.stock >= lot_size;
    
    if pending_cnt == 0 && lower_band > 0 {
        if can_buy {
            orders.submit_limit_buy(lower_band, lot_size);
        }
        if can_sell {
            orders.submit_limit_sell(upper_band, lot_size);
        }
        
        if can_buy || can_sell {
            let new_pending = my_orders.pending_count();
            let k = 0;
            while k < new_pending {
                let oid = my_orders.pending_id(k);
                let exists = false;
                let m = 0;
                while m < order_place_ticks.len() {
                    if order_place_ticks[m].id == oid {
                        exists = true;
                        break;
                    }
                    m += 1;
                }
                if !exists {
                    order_place_ticks.push(#{ id: oid, tick: current_tick });
                }
                k += 1;
            }
        }
    }
}
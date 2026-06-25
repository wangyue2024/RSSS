let initialized = false;
let lot_size = 100;
let last_trade_was_loss = false;
let entry_price = 0;
let in_position = false;
let position_side = 0;
let avg_volume_20 = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = 100;
        last_trade_was_loss = false;
        entry_price = 0;
        in_position = false;
        position_side = 0;
        avg_volume_20 = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() >= 20 {
        let volumes = [];
        let idx = 0;
        while idx < 20 {
            volumes.push(market.history_volume(idx));
            idx += 1;
        }
        avg_volume_20 = arr_mean(volumes);
    }
    
    if in_position {
        let current_pnl = 0;
        if position_side == 1 {
            current_pnl = (market.price - entry_price) * account.stock;
        } else if position_side == -1 {
            current_pnl = (entry_price - market.price) * account.stock;
        }
        
        let exit_condition = false;
        if position_side == -1 {
            if current_pnl > 0 {
                let take_profit = entry_price * 98 / 100;
                if market.price <= take_profit {
                    exit_condition = true;
                }
            }
            let stop_loss = entry_price * 102 / 100;
            if market.price >= stop_loss {
                exit_condition = true;
                last_trade_was_loss = true;
            }
        }
        
        if exit_condition {
            if account.stock > 0 {
                orders.submit_limit_sell(market.price - 100, account.stock);
            } else {
                orders.submit_limit_buy(market.price + 100, abs_val(account.stock));
            }
            in_position = false;
            position_side = 0;
            return;
        }
    }
    
    let volume_threshold = avg_volume_20 * 10 / 100;
    let exhaustion_signal = market.high_20 > market.ma_60 && market.volume < volume_threshold && market.volume > 0;
    
    if exhaustion_signal && !in_position {
        let current_lot = lot_size;
        if last_trade_was_loss {
            current_lot = lot_size * 2;
        }
        
        if current_lot > 0 {
            let sell_price = market.price - 50;
            orders.submit_limit_sell(sell_price, current_lot);
            entry_price = sell_price;
            in_position = true;
            position_side = -1;
            last_trade_was_loss = false;
        }
    }
    
    if in_position && position_side == -1 {
        if account.stock < 0 {
            let current_value = abs_val(account.stock) * market.price;
            let entry_value = abs_val(account.stock) * entry_price;
            if current_value > entry_value {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
                lot_size = 100;
            }
        }
    }
}
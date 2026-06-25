let initialized = false;
let base_lot_size = 0;
let last_realized_pnl = 0;
let last_trade_was_loss = false;
let entry_tick = 0;
let entry_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_realized_pnl = account.realized_pnl;
        base_lot_size = (account.cash * rng.rand_int(25, 50)) / (100 * market.price);
        if base_lot_size < 100 {
            base_lot_size = 100;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.realized_pnl != last_realized_pnl {
        let change = account.realized_pnl - last_realized_pnl;
        last_trade_was_loss = (change < 0);
        last_realized_pnl = account.realized_pnl;
    }
    
    let current_lot_size = base_lot_size;
    if last_trade_was_loss {
        current_lot_size = base_lot_size * 2;
        if current_lot_size * market.price > account.cash {
            current_lot_size = account.cash / market.price;
        }
        if current_lot_size < 100 {
            current_lot_size = 100;
        }
    }
    
    if account.stock < 0 {
        let exit_condition = false;
        
        if market.tick - entry_tick >= 10 {
            exit_condition = true;
        }
        
        if (market.price * 100) > (entry_price * 102) {
            exit_condition = true;
        }
        
        if exit_condition {
            orders.submit_market_buy(-account.stock);
            entry_tick = 0;
            entry_price = 0;
        }
    } else if account.stock == 0 {
        if market.price > market.ma_60 {
            let avg_volume_20 = 0;
            let history_len = market.history_len();
            if history_len >= 20 {
                let sum = 0;
                for i in 0..20 {
                    sum = sum + market.history_volume(history_len - 1 - i);
                }
                avg_volume_20 = sum / 20;
            }
            
            if avg_volume_20 > 0 && market.volume < (avg_volume_20 * 10 / 100) {
                if current_lot_size > 0 {
                    orders.submit_market_sell(current_lot_size);
                    entry_tick = market.tick;
                    entry_price = market.price;
                }
            }
        }
    }
}
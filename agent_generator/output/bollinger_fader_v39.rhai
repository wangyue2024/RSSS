let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let last_fill_side = my_orders.fill_side(last_fill_idx);
        let last_fill_price = my_orders.fill_price(last_fill_idx);
        
        if last_fill_side == 0 {
            if market.price < account.avg_cost {
                last_trade_was_loss = true;
                current_lot_size = current_lot_size * 2;
            } else {
                last_trade_was_loss = false;
                current_lot_size = base_lot_size;
            }
        } else {
            if last_fill_price > account.avg_cost {
                last_trade_was_loss = false;
                current_lot_size = base_lot_size;
            } else {
                last_trade_was_loss = true;
                current_lot_size = current_lot_size * 2;
            }
        }
    }
    
    let ma = market.ma_20;
    let std = market.std_dev;
    
    if ma == 0 || std == 0 {
        return;
    }
    
    let upper_band = ma + 2 * std;
    let lower_band = ma - 2 * std;
    
    if market.price > lower_band && market.price < upper_band {
        let buy_amount = current_lot_size;
        let sell_amount = current_lot_size;
        
        if account.cash >= lower_band * buy_amount && buy_amount > 0 {
            orders.submit_limit_buy(lower_band, buy_amount);
        }
        
        if account.stock >= sell_amount && sell_amount > 0 {
            orders.submit_limit_sell(upper_band, sell_amount);
        }
    }
}
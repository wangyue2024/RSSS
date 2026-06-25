let initialized = false;
let base_lot_size = 100;
let lot_size = base_lot_size;
let last_trade_loss = false;
let position_avg_cost = 0;
let threshold_bps = 50;
let pending_buy_order_id = 0;
let pending_sell_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let vwap = market.vwap;
    let price = market.price;
    
    let has_pending_buy = false;
    let has_pending_sell = false;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        } else {
            let side = my_orders.pending_side(i);
            if side == 0 {
                has_pending_buy = true;
                pending_buy_order_id = my_orders.pending_id(i);
            } else {
                has_pending_sell = true;
                pending_sell_order_id = my_orders.pending_id(i);
            }
        }
        i += 1;
    }
    
    let fill_count = my_orders.fill_count();
    let j = 0;
    while j < fill_count {
        let fill_side = my_orders.fill_side(j);
        let fill_price = my_orders.fill_price(j);
        let fill_amount = my_orders.fill_amount(j);
        
        if fill_side == 0 {
            if account.stock > 0 {
                position_avg_cost = account.avg_cost;
            }
        } else {
            if account.stock == 0 && position_avg_cost > 0 {
                let profit = (fill_price - position_avg_cost) * fill_amount;
                if profit < 0 {
                    last_trade_loss = true;
                } else {
                    last_trade_loss = false;
                }
                position_avg_cost = 0;
            }
        }
        j += 1;
    }
    
    if last_trade_loss {
        lot_size = base_lot_size * 2;
    } else {
        lot_size = base_lot_size;
    }
    
    let buy_condition = price * 10000 < vwap * (10000 - threshold_bps);
    let sell_condition = price * 10000 >= vwap * 10000;
    
    if account.stock == 0 {
        if buy_condition && !has_pending_buy {
            orders.submit_limit_buy(price, lot_size);
        }
    } else {
        if sell_condition && !has_pending_sell {
            orders.submit_limit_sell(price, account.stock);
        }
    }
}
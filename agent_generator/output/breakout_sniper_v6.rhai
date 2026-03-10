let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_loss = false;
let price_history = [];
let stop_loss_order_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_lot_size = base_lot_size;
        last_trade_loss = false;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    price_history.push(current_price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        let fill_price = my_orders.fill_price(i);
        let fill_amount = my_orders.fill_amount(i);
        
        if fill_side == 1 && account.stock == 0 {
            if fill_price < account.avg_cost {
                last_trade_loss = true;
                current_lot_size = current_lot_size * 2;
            } else {
                last_trade_loss = false;
                current_lot_size = base_lot_size;
            }
        }
        i += 1;
    }
    
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        if oid == stop_loss_order_id {
            j += 1;
            continue;
        }
        orders.submit_cancel(oid);
        j += 1;
    }
    
    if price_history.len() >= 5 {
        let old_price = price_history[0];
        let price_change = (current_price - old_price) * 10000 / old_price;
        if price_change > 200 {
            let buy_amount = current_lot_size;
            if account.cash > current_price * buy_amount {
                orders.submit_market_buy(buy_amount);
                stop_loss_order_id = -1;
            }
            return;
        }
    }
    
    if market.tick % 50 != 0 { return; }
    
    if current_price > market.high_20 && account.cash > current_price * current_lot_size {
        if last_trade_loss {
            current_lot_size = current_lot_size * 2;
        } else {
            current_lot_size = base_lot_size;
        }
        
        orders.submit_market_buy(current_lot_size);
        
        if stop_loss_order_id != -1 {
            orders.submit_cancel(stop_loss_order_id);
        }
        
        if account.stock > 0 {
            let stop_price = account.avg_cost * 98 / 100;
            let sell_order_id = orders.submit_limit_sell(stop_price, account.stock);
            stop_loss_order_id = sell_order_id;
        }
    }
}
let initialized = false;
let prev_price = 0;

fn round_to_dollar(price) {
    let factor = 1_000_000;
    return ((price + factor / 2) / factor) * factor;
}

fn on_tick() {
    if !market.trading_enabled {
        return;
    }
    
    if !initialized {
        initialized = true;
        prev_price = market.price;
        return;
    }
    
    let current_price = market.price;
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let order_qty = 100;
    let delta = current_price - prev_price;
    
    if delta < 0 {
        let buy_price = current_price * 9995 / 10000;
        let rounded_buy_price = round_to_dollar(buy_price);
        let max_afford = account.cash / rounded_buy_price;
        let qty_to_buy = order_qty;
        if max_afford < qty_to_buy {
            qty_to_buy = max_afford;
        }
        if qty_to_buy > 0 {
            orders.submit_limit_buy(rounded_buy_price, qty_to_buy);
        }
    } else if delta > 0 {
        let sell_price = current_price * 10005 / 10000;
        let rounded_sell_price = round_to_dollar(sell_price);
        let qty_to_sell = order_qty;
        if account.stock < qty_to_sell {
            qty_to_sell = account.stock;
        }
        if qty_to_sell > 0 {
            orders.submit_limit_sell(rounded_sell_price, qty_to_sell);
        }
    }
    
    prev_price = current_price;
}
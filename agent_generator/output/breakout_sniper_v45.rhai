let initialized = false;
let price_buffer = [];
let high_20_buffer = [];
let pending_buy_order = 0;
let position_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_buffer.push(market.price);
    high_20_buffer.push(market.high_20);
    
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        high_20_buffer.remove(0);
    }
    
    if price_buffer.len() < 5 { return; }
    
    let delayed_price = price_buffer[0];
    let delayed_high_20 = high_20_buffer[0];
    
    if account.stock > 0 {
        let stop_loss_price = position_avg_cost - 50_000;
        if delayed_price < stop_loss_price {
            orders.submit_market_sell(account.stock);
            pending_buy_order = 0;
        }
    } else {
        if delayed_price > delayed_high_20 {
            let buy_amount = account.cash * 8 / 10 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let i = 0;
        while i < fill_count {
            let side = my_orders.fill_side(i);
            if side == 0 {
                position_avg_cost = account.avg_cost;
            }
            i += 1;
        }
    }
}
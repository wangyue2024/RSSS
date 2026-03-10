let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_profitable = true;
let spread_micros = 100000;
let pending_cancel_ids = [];

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = 50 + rng.rand_int(0, 150);
        current_lot_size = base_lot_size;
        spread_micros = 50000 + rng.rand_int(0, 150000);
    }
    
    if !market.trading_enabled { return; }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_side = my_orders.fill_side(fill_cnt - 1);
        let last_fill_price = my_orders.fill_price(fill_cnt - 1);
        
        if last_fill_side == "sell" {
            if last_fill_price <= account.avg_cost {
                last_trade_profitable = false;
                current_lot_size = current_lot_size * 2;
            } else {
                last_trade_profitable = true;
                current_lot_size = base_lot_size;
            }
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        pending_cancel_ids.push(my_orders.pending_id(i));
        i += 1;
    }
    
    i = 0;
    while i < pending_cancel_ids.len() {
        orders.submit_cancel(pending_cancel_ids[i]);
        i += 1;
    }
    pending_cancel_ids = [];
    
    let mid_price = market.price;
    let buy_price = round_to_dollar(mid_price - spread_micros);
    let sell_price = round_to_dollar(mid_price + spread_micros);
    
    let max_buy_amount = account.cash / buy_price;
    let buy_amount = current_lot_size;
    if buy_amount > max_buy_amount {
        buy_amount = max_buy_amount;
    }
    
    if buy_amount > 0 {
        orders.submit_limit_buy(buy_price, buy_amount);
    }
    
    if sell_price > account.avg_cost && account.stock > 0 {
        let sell_amount = current_lot_size;
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}
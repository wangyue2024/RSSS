let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_price = 0;
let last_trade_side = 0;
let martingale_active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(80, 120);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let last_fill_idx = fill_count - 1;
        last_trade_price = my_orders.fill_price(last_fill_idx);
        last_trade_side = my_orders.fill_side(last_fill_idx);
        
        if last_trade_side == 1 {
            if market.price < last_trade_price {
                martingale_active = true;
                current_lot_size = current_lot_size * 2;
            } else {
                martingale_active = false;
                current_lot_size = base_lot_size;
            }
        } else if last_trade_side == -1 {
            if market.price > last_trade_price {
                martingale_active = true;
                current_lot_size = current_lot_size * 2;
            } else {
                martingale_active = false;
                current_lot_size = base_lot_size;
            }
        }
    }
    
    let inventory = account.stock;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    
    let buy_offset = 50;
    let sell_offset = 50;
    
    if inventory > 1000 {
        buy_offset = 100;
        sell_offset = 25;
    } else if inventory <= 0 {
        buy_offset = 25;
        sell_offset = 100;
    }
    
    let buy_price = market.bid_price_0 - buy_offset;
    let sell_price = market.ask_price_0 + sell_offset;
    
    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, current_lot_size);
    }
    
    if sell_price > account.avg_cost && sell_price > 0 {
        orders.submit_limit_sell(sell_price, current_lot_size);
    }
}
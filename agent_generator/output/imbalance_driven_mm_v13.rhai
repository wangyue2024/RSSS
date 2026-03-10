let initialized = false;
let base_lot_size = 0;
let price_adjust_factor = 0;
let max_position_shift = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50000000, 150000000);
        price_adjust_factor = rng.rand_int(100000, 500000);
        max_position_shift = rng.rand_int(5000000, 15000000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let imbalance = market.order_imbalance;
    let current_price = market.price;
    
    let bid_shift = imbalance * price_adjust_factor / 10000;
    let ask_shift = imbalance * price_adjust_factor / 10000;
    
    let clamped_bid_shift = clamp_val(bid_shift, -max_position_shift, max_position_shift);
    let clamped_ask_shift = clamp_val(ask_shift, -max_position_shift, max_position_shift);
    
    let spread = 50000;
    let bid_price = current_price + clamped_bid_shift - spread / 2;
    let ask_price = current_price + clamped_ask_shift + spread / 2;
    
    let min_price = 10000;
    let final_bid_price = if bid_price < min_price { min_price } else { bid_price };
    let final_ask_price = if ask_price < min_price { min_price } else { ask_price };
    
    let cash_available = account.cash;
    let stock_available = account.stock;
    
    let bid_amount_shares = base_lot_size;
    let max_buy_by_cash = cash_available * 50 / 100 / final_bid_price;
    let actual_bid_amount = if bid_amount_shares > max_buy_by_cash { max_buy_by_cash } else { bid_amount_shares };
    
    let ask_amount_shares = base_lot_size;
    let max_sell_by_stock = stock_available * 50 / 100;
    let actual_ask_amount = if ask_amount_shares > max_sell_by_stock { max_sell_by_stock } else { ask_amount_shares };
    
    if actual_bid_amount > 0 && final_bid_price > 0 {
        orders.submit_limit_buy(final_bid_price, actual_bid_amount);
    }
    
    if actual_ask_amount > 0 && final_ask_price > 0 {
        orders.submit_limit_sell(final_ask_price, actual_ask_amount);
    }
}
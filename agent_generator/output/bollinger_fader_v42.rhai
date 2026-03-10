let initialized = false;
let last_realized_pnl = 0;
let martingale_multiplier = 1;
let base_lot_size = 100;
let price_window = [];
let delayed_ma_20 = 0;
let delayed_std_dev = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_realized_pnl = account.realized_pnl;
        martingale_multiplier = 1;
        base_lot_size = 100;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_window.push(market.price);
    if price_window.len() > 5 {
        price_window.remove(0);
    }
    
    if price_window.len() == 5 {
        let delayed_price = price_window[0];
        
        if market.history_len() >= 25 {
            let history_prices = [];
            let j = 5;
            while j < 25 {
                history_prices.push(market.history_price(j));
                j += 1;
            }
            
            delayed_ma_20 = arr_mean(history_prices);
            delayed_std_dev = arr_std_dev(history_prices);
            
            let lower_band = delayed_ma_20 - 2 * delayed_std_dev;
            let upper_band = delayed_ma_20 + 2 * delayed_std_dev;
            
            let change = account.realized_pnl - last_realized_pnl;
            if change < 0 {
                martingale_multiplier = martingale_multiplier * 2;
                if martingale_multiplier > 8 {
                    martingale_multiplier = 8;
                }
            } else {
                martingale_multiplier = 1;
            }
            
            let current_lot_size = base_lot_size * martingale_multiplier;
            
            if delayed_price <= lower_band && account.cash >= lower_band * current_lot_size {
                orders.submit_limit_buy(lower_band, current_lot_size);
            }
            
            if delayed_price >= upper_band && account.stock >= current_lot_size {
                orders.submit_limit_sell(upper_band, current_lot_size);
            }
            
            last_realized_pnl = account.realized_pnl;
        }
    }
}
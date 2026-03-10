let initialized = false;
let lot_size = 0;
let last_trade_profit = true;
let last_order_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
        let base_size = rng.rand_int(100, 500);
        let multiplier = rng.rand_int(5, 10);
        lot_size = base_size * multiplier;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        let current_price = market.price;
        if fill_side == 0 {
            if current_price < account.avg_cost {
                last_trade_profit = false;
            } else {
                last_trade_profit = true;
            }
        } else {
            let avg_cost = account.avg_cost;
            if fill_price > avg_cost {
                last_trade_profit = true;
            } else {
                last_trade_profit = false;
            }
        }
    }
    
    if !last_trade_profit {
        lot_size = lot_size * 2;
    }
    
    if market.tick - last_order_tick >= 50 {
        last_order_tick = market.tick;
        
        let lower_band = market.ma_20 - 2 * market.std_dev;
        let upper_band = market.ma_20 + 2 * market.std_dev;
        
        let cash_to_use = account.cash * 50 / 100;
        let max_buy_by_cash = cash_to_use / market.price;
        let buy_amount = lot_size;
        if max_buy_by_cash < buy_amount {
            buy_amount = max_buy_by_cash;
        }
        if buy_amount > 0 {
            orders.submit_limit_buy(lower_band, buy_amount);
        }
        
        let stock_to_sell = account.stock * 50 / 100;
        let sell_amount = lot_size;
        if stock_to_sell < sell_amount {
            sell_amount = stock_to_sell;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(upper_band, sell_amount);
        }
    }
}
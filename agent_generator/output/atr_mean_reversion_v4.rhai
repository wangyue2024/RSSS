let initialized = false;
let base_lot = 100;
let last_trade_profitable = true;
let last_position_side = 0;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = 100;
        last_trade_profitable = true;
        last_position_side = 0;
        last_avg_cost = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_lot = base_lot;
    if !last_trade_profitable {
        current_lot = base_lot * 2;
    }
    
    let deviation = abs_val(market.price - market.ma_20);
    let atr_threshold = (market.atr_14 * 3) / 2;
    
    if deviation * 2 > atr_threshold * 3 {
        if market.price > market.ma_20 {
            if account.stock >= 0 {
                let sell_amount = current_lot;
                if sell_amount > 0 {
                    orders.submit_market_sell(sell_amount);
                    last_position_side = -1;
                    last_avg_cost = market.price;
                }
            }
        } else {
            if account.stock <= 0 {
                let buy_amount = current_lot;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                    last_position_side = 1;
                    last_avg_cost = market.price;
                }
            }
        }
    }
    
    if account.stock != 0 {
        if last_position_side == 1 && market.price < last_avg_cost {
            last_trade_profitable = false;
        } else if last_position_side == -1 && market.price > last_avg_cost {
            last_trade_profitable = false;
        } else {
            last_trade_profitable = true;
        }
    }
}
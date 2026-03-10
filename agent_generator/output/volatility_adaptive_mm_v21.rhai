let initialized = false;
let min_spread = 10_000;
let max_spread = 200_000;
let base_spread = 50_000;
let order_amount = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    if market.tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let vol_factor = market.std_dev;
    if vol_factor < 0 { vol_factor = 0; }
    
    let spread_adjust = vol_factor * 5;
    let spread = base_spread + spread_adjust;
    if spread < min_spread { spread = min_spread; }
    if spread > max_spread { spread = max_spread; }
    
    let half_spread = spread / 2;
    
    let mid_price = market.price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    }
    
    let buy_price = mid_price - half_spread;
    let sell_price = mid_price + half_spread;
    
    if buy_price > 0 && account.cash >= buy_price * order_amount {
        orders.submit_limit_buy(buy_price, order_amount);
    }
    
    if sell_price > 0 && account.stock >= order_amount {
        orders.submit_limit_sell(sell_price, order_amount);
    }
}
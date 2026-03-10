let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let max_lot = 1600;
let last_trade_profit = 0;
let last_avg_cost = 0;
let imbalance_factor = 10;
let base_spread = 2000;
let loss_streak = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = 100;
        current_lot = base_lot;
        max_lot = 1600;
        last_trade_profit = 0;
        last_avg_cost = 0;
        imbalance_factor = rng.rand_int(5, 20);
        base_spread = rng.rand_int(1500, 3000);
        loss_streak = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let mid_price = market.price;
    let imbalance = market.order_imbalance;
    
    let adjustment = imbalance * imbalance_factor;
    let adjusted_mid = mid_price + adjustment;
    
    let half_spread = base_spread / 2;
    let bid_price = adjusted_mid - half_spread;
    let ask_price = adjusted_mid + half_spread;
    
    if bid_price <= 0 || ask_price <= 0 { return; }
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        let spread = market.ask_price_0 - market.bid_price_0;
        if spread > 0 && spread < base_spread * 2 {
            return;
        }
    }
    
    let position = account.stock;
    let max_position = 5000;
    
    if position < max_position {
        let buy_amount = current_lot;
        if buy_amount > 0 {
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }
    
    if position > -max_position {
        let sell_amount = current_lot;
        if sell_amount > 0 {
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        if last_avg_cost != 0 && account.stock == 0 {
            let profit_per_share = 0;
            if fill_side == 1 {
                profit_per_share = fill_price - last_avg_cost;
            } else if fill_side == 0 {
                profit_per_share = last_avg_cost - fill_price;
            }
            
            if profit_per_share < 0 {
                loss_streak += 1;
                current_lot = current_lot * 2;
                if current_lot > max_lot {
                    current_lot = max_lot;
                }
            } else {
                loss_streak = 0;
                current_lot = base_lot;
            }
        }
        
        if account.stock != 0 {
            last_avg_cost = account.avg_cost;
        } else {
            last_avg_cost = 0;
        }
    }
}
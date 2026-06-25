let rebalance_tick = 0;
let last_action_tick = -100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if current_tick - last_action_tick < 50 {
        return;
    }
    
    last_action_tick = current_tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let stock_value = account.stock * market.price;
    let total_eq = account.cash + stock_value;
    
    if total_eq == 0 { return; }
    
    let stock_pct = (stock_value * 100) / total_eq;
    
    let target_shares = 0;
    let order_price = 0;
    
    if stock_pct > 55 && market.price > account.avg_cost {
        let target_stock_value = total_eq / 2;
        let excess_stock_value = stock_value - target_stock_value;
        if excess_stock_value > 0 {
            target_shares = excess_stock_value / market.price;
            if target_shares == 0 { return; }
            
            if target_shares > account.stock {
                target_shares = account.stock;
            }
            
            let ask_price = market.ask_price_0;
            if ask_price == 0 {
                order_price = market.price;
            } else {
                order_price = ask_price;
            }
            
            if order_price > account.avg_cost && target_shares > 0 {
                orders.submit_limit_sell(order_price, target_shares);
            }
        }
    } else if stock_pct < 45 {
        let target_stock_value = total_eq / 2;
        let deficit_stock_value = target_stock_value - stock_value;
        if deficit_stock_value > 0 {
            target_shares = deficit_stock_value / market.price;
            if target_shares == 0 { return; }
            
            let max_affordable = account.cash / market.price;
            if target_shares > max_affordable {
                target_shares = max_affordable;
            }
            
            let bid_price = market.bid_price_0;
            if bid_price == 0 {
                order_price = market.price - 1000;
            } else {
                order_price = bid_price + 1;
            }
            
            if target_shares > 0 {
                orders.submit_limit_buy(order_price, target_shares);
            }
        }
    }
}
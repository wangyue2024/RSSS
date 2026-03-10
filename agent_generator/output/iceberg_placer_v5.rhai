let initialized = false;
let total_to_sell = 0;
let visible_size = 0;
let remaining_to_sell = 0;
let current_sell_order_id = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = 50000;
        visible_size = 100;
        remaining_to_sell = total_to_sell;
        fomo_triggered = false;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 20 {
        price_history.remove(0);
    }
    
    if !fomo_triggered && price_history.len() >= 10 {
        let old_price = price_history[0];
        let current_price = market.price;
        let price_change_pct = (current_price - old_price) * 100 / old_price;
        
        if price_change_pct > 2 {
            fomo_triggered = true;
            let count = my_orders.pending_count();
            let i = 0;
            while i < count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            orders.submit_market_buy(1000);
            return;
        }
    }
    
    if fomo_triggered { return; }
    
    let fill_count = my_orders.fill_count();
    let found_fill = false;
    
    if fill_count > 0 {
        let i = 0;
        while i < fill_count {
            let fill_side = my_orders.fill_side(i);
            if fill_side == "sell" {
                let fill_amount = my_orders.fill_amount(i);
                remaining_to_sell -= fill_amount;
                found_fill = true;
                
                let pending_count = my_orders.pending_count();
                let j = 0;
                while j < pending_count {
                    let oid = my_orders.pending_id(j);
                    if my_orders.pending_side(j) == "sell" {
                        orders.submit_cancel(oid);
                    }
                    j += 1;
                }
            }
            i += 1;
        }
    }
    
    let has_pending_sell = false;
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        if my_orders.pending_side(i) == "sell" {
            has_pending_sell = true;
            break;
        }
        i += 1;
    }
    
    if found_fill || !has_pending_sell {
        if remaining_to_sell > 0 {
            let order_size = visible_size;
            if order_size > remaining_to_sell {
                order_size = remaining_to_sell;
            }
            
            if market.ask_price_0 > 0 {
                orders.submit_limit_sell(market.ask_price_0, order_size);
            }
        }
    }
}
let initialized = false;
let target_buy_price = 0;
let target_sell_price = 0;
let pending_buy_id = -1;
let pending_sell_id = -1;
let pending_buy_placed = 0;
let pending_sell_placed = 0;
const ORDER_QTY = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if market.ma_20 == 0 || market.std_dev == 0 {
        return;
    }
    
    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;
    
    if current_tick % 50 == 0 {
        let buy_price = lower_band + 1;
        let sell_price = upper_band;
        
        if pending_buy_id != -1 {
            orders.submit_cancel(pending_buy_id);
        }
        if pending_sell_id != -1 {
            orders.submit_cancel(pending_sell_id);
        }
        
        if buy_price > 0 && buy_price < market.ask_price_0 {
            pending_buy_id = orders.submit_limit_buy(buy_price, ORDER_QTY);
            pending_buy_placed = current_tick;
        }
        
        if sell_price > 0 && sell_price > market.bid_price_0 {
            pending_sell_id = orders.submit_limit_sell(sell_price, ORDER_QTY);
            pending_sell_placed = current_tick;
        }
        
        target_buy_price = buy_price;
        target_sell_price = sell_price;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed = my_orders.pending_placed_tick(i);
        
        if current_tick - placed >= 3 {
            orders.submit_cancel(oid);
            
            if oid == pending_buy_id && target_buy_price > 0 && target_buy_price < market.ask_price_0 {
                pending_buy_id = orders.submit_limit_buy(target_buy_price, ORDER_QTY);
                pending_buy_placed = current_tick;
            }
            
            if oid == pending_sell_id && target_sell_price > 0 && target_sell_price > market.bid_price_0 {
                pending_sell_id = orders.submit_limit_sell(target_sell_price, ORDER_QTY);
                pending_sell_placed = current_tick;
            }
        }
        i += 1;
    }
    
    let fill_count = my_orders.fill_count();
    let j = 0;
    while j < fill_count {
        let fill_id = my_orders.fill_id(j);
        if fill_id == pending_buy_id {
            pending_buy_id = -1;
        }
        if fill_id == pending_sell_id {
            pending_sell_id = -1;
        }
        j += 1;
    }
}
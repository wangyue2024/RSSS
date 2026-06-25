let price_history = [];
let initialized = false;
let last_placed_tick = -1;
let order_id_map = [];
let panic_mode = false;
let panic_until_tick = 0;
let DELAY_TICKS = 5;
let INVENTORY_HIGH = 1000;
let FOMO_THRESHOLD = 200;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        price_history.push(market.price);
        return;
    }
    
    price_history.push(market.price);
    if price_history.len() > DELAY_TICKS + 2 {
        price_history.remove(0);
    }
    
    if my_orders.pending_count() > 0 {
        let i = 0;
        while i < my_orders.pending_count() {
            let placed_tick = my_orders.pending_placed_tick(i);
            if market.tick - placed_tick > 3 {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
            }
            i += 1;
        }
    }
    
    if panic_mode {
        if market.tick >= panic_until_tick {
            panic_mode = false;
        } else {
            orders.submit_market_buy(100);
            return;
        }
    }
    
    if price_history.len() >= DELAY_TICKS + 2 {
        let delayed_price = price_history[price_history.len() - DELAY_TICKS - 1];
        let older_price = price_history[price_history.len() - DELAY_TICKS - 2];
        let price_change = abs_val(delayed_price - older_price) * 10000 / older_price;
        
        if price_change > FOMO_THRESHOLD {
            panic_mode = true;
            panic_until_tick = market.tick + 10;
            orders.submit_market_buy(100);
            return;
        }
    }
    
    if price_history.len() <= DELAY_TICKS {
        return;
    }
    
    let delayed_price = price_history[price_history.len() - DELAY_TICKS - 1];
    let inventory = account.stock;
    
    let base_spread_buy = delayed_price * 50 / 10000;
    let base_spread_sell = delayed_price * 50 / 10000;
    
    let buy_distance = base_spread_buy;
    let sell_distance = base_spread_sell;
    
    if inventory > INVENTORY_HIGH {
        buy_distance = base_spread_buy * 3 / 2;
        sell_distance = base_spread_sell / 2;
    } else if inventory <= 0 {
        buy_distance = base_spread_buy / 2;
        sell_distance = base_spread_sell * 3 / 2;
    }
    
    let buy_price = delayed_price - buy_distance;
    let sell_price = delayed_price + sell_distance;
    
    buy_price = clamp_val(buy_price, market.bid_price_4, market.ask_price_0);
    sell_price = clamp_val(sell_price, market.bid_price_0, market.ask_price_4);
    
    let has_buy_order = false;
    let has_sell_order = false;
    
    let i = 0;
    while i < my_orders.pending_count() {
        let side = my_orders.pending_side(i);
        let price = my_orders.pending_price(i);
        if side == 0 && price == buy_price {
            has_buy_order = true;
        }
        if side == 1 && price == sell_price {
            has_sell_order = true;
        }
        i += 1;
    }
    
    if !has_buy_order && account.cash >= buy_price * 100 {
        orders.submit_limit_buy(buy_price, 100);
    }
    
    if !has_sell_order && account.stock >= 100 {
        orders.submit_limit_sell(sell_price, 100);
    }
}
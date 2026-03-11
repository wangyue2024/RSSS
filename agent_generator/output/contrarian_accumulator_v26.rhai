let initialized = false;
let cooldown_ticks = 0;
let last_trade_tick = 0;
let buy_target = 0;
let sell_target = 0;
let my_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        cooldown_ticks = rng.rand_int(150, 250);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if current_tick < last_trade_tick + cooldown_ticks {
        return;
    }
    
    let price_jump = false;
    if market.history_len() >= 10 {
        let old_price = market.history_price(9);
        if old_price > 0 {
            let change_pct = (market.price - old_price) * 100 / old_price;
            if change_pct > 200 {
                price_jump = true;
            }
        }
    }
    
    if price_jump {
        let buy_amount = rng.rand_int(20, 100);
        orders.submit_market_buy(buy_amount);
        last_trade_tick = current_tick;
        return;
    }
    
    my_position = account.stock;
    let rsi = market.rsi_14;
    
    if rsi < 3000 && my_position < 1000 {
        let base_price = market.price * 99 / 100;
        let rounded_price = (base_price / 1_000_000) * 1_000_000;
        if rounded_price <= base_price {
            rounded_price = rounded_price + 1_000_000;
        }
        let buy_amount = rng.rand_int(20, 100);
        orders.submit_limit_buy(rounded_price, buy_amount);
        last_trade_tick = current_tick;
    } else if rsi > 7000 && my_position > 0 {
        let base_price = market.price * 101 / 100;
        let rounded_price = (base_price / 1_000_000) * 1_000_000;
        if rounded_price >= base_price {
            rounded_price = rounded_price - 1_000_000;
        }
        let sell_amount = rng.rand_int(20, 100);
        if sell_amount > my_position {
            sell_amount = my_position;
        }
        orders.submit_limit_sell(rounded_price, sell_amount);
        last_trade_tick = current_tick;
    }
}
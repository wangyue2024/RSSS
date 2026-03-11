let initialized = false;
let base_lot = 1000;
let lot_size = base_lot;
let last_trade_avg_cost = 0;
let last_trade_side = 0;
let panic_threshold = 0;
let delayed_prices = [];
let pending_oid = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = 1000;
        lot_size = base_lot;
        last_trade_avg_cost = 0;
        last_trade_side = 0;
        panic_threshold = -rng.rand_int(10000, 50000);
        pending_oid = 0;
    }
    
    if !market.trading_enabled { return; }
    
    delayed_prices.push(market.price);
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }
    
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
        last_trade_avg_cost = my_orders.fill_price(last_fill_idx);
        last_trade_side = my_orders.fill_side(last_fill_idx);
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock != 0 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        } else {
            orders.submit_market_buy(-account.stock);
        }
        lot_size = base_lot;
        return;
    }
    
    if delayed_prices.len() < 5 { return; }
    
    let delayed_price = delayed_prices[0];
    if last_trade_avg_cost != 0 && last_trade_side != 0 {
        if (last_trade_side == 0 && delayed_price < last_trade_avg_cost) ||
           (last_trade_side == 1 && delayed_price > last_trade_avg_cost) {
            lot_size = lot_size * 2;
        } else {
            lot_size = base_lot;
        }
    }
    
    let range_spread = market.high_20 - market.low_20;
    if range_spread < 50000 {
        lot_size = lot_size * 150 / 100;
    }
    
    let buy_price = market.low_20 + 1000;
    let sell_price = market.high_20 - 1000;
    
    if account.stock == 0 {
        orders.submit_limit_buy(buy_price, lot_size);
        orders.submit_limit_sell(sell_price, lot_size);
    } else if account.stock > 0 {
        orders.submit_limit_sell(sell_price, account.stock);
    } else {
        orders.submit_limit_buy(buy_price, -account.stock);
    }
}
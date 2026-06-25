let initialized = false;
let threshold = 0;
let offset = 0;
let trade_active = false;
let attack_phase = 0;
let target_price = 0;
let lot_percentage = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold = rng.rand_int(5_000, 20_000);
        offset = rng.rand_int(5_000, 15_000);
        lot_percentage = rng.rand_int(25, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let current_price = market.price;
    let total_bid_vol = market.bid_vol_0 + market.bid_vol_1 + market.bid_vol_2 + market.bid_vol_3 + market.bid_vol_4;
    let total_ask_vol = market.ask_vol_0 + market.ask_vol_1 + market.ask_vol_2 + market.ask_vol_3 + market.ask_vol_4;
    
    if trade_active {
        if attack_phase == 1 {
            if market.price <= target_price {
                let buy_amount = (account.total_equity * lot_percentage * 12 / 100) / current_price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                trade_active = false;
                attack_phase = 0;
            }
        }
    } else {
        if total_bid_vol > total_ask_vol * 15 / 10 && market.order_imbalance < -20000 {
            let sell_value = account.total_equity * lot_percentage / 100;
            let sell_amount = sell_value / current_price;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                trade_active = true;
                attack_phase = 1;
                target_price = current_price * (100000 - offset) / 100000;
            }
        }
    }
}
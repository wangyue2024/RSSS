let initialized = false;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let init_pct = rng.rand_int(250, 500);
        let max_cash_for_trade = account.cash * init_pct / 1000;
        let price_at_init = market.price;
        if price_at_init > 0 {
            lot_size = max_cash_for_trade / price_at_init;
        } else {
            lot_size = 100;
        }
        if lot_size < 100 {
            lot_size = 100;
        }
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.ma_20 <= 0 || market.std_dev <= 0 {
        return;
    }
    
    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;
    
    if lower_band <= 0 || upper_band <= lower_band {
        return;
    }
    
    let max_buy_by_cash = account.cash / lower_band;
    let buy_amount = lot_size;
    if max_buy_by_cash < buy_amount {
        buy_amount = max_buy_by_cash;
    }
    if buy_amount > 0 {
        orders.submit_limit_buy(lower_band, buy_amount);
    }
    
    let sell_amount = lot_size;
    if account.stock < sell_amount {
        sell_amount = account.stock;
    }
    if sell_amount > 0 {
        orders.submit_limit_sell(upper_band, sell_amount);
    }
}
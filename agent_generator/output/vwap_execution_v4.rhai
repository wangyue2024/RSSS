let initialized = false;
let base_lot_size = 0;
let martingale_multiplier = 1;
let last_trade_avg_cost = 0;
let last_trade_profit = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let cash_for_trade = account.cash * 50 / 100;
        let shares_affordable = cash_for_trade / market.price;
        base_lot_size = rng.rand_int(1000, shares_affordable);
        last_trade_avg_cost = account.avg_cost;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.volume == 0 { return; }
    
    let current_loss = 0;
    if account.stock > 0 && market.price < account.avg_cost {
        current_loss = 1;
    }
    
    if current_loss == 1 && last_trade_profit == 0 {
        martingale_multiplier = martingale_multiplier * 2;
    } else {
        martingale_multiplier = 1;
    }
    
    let vol_history = [];
    let history_len = market.history_len();
    let lookback = 10;
    let j = 0;
    while j < lookback && j < history_len {
        vol_history.push(market.history_volume(j));
        j += 1;
    }
    
    let avg_hist_vol = 10000;
    if vol_history.len() > 0 {
        avg_hist_vol = arr_mean(vol_history);
        if avg_hist_vol == 0 { avg_hist_vol = 1; }
    }
    
    let volume_ratio = market.volume * 10000 / avg_hist_vol;
    let dynamic_lot = base_lot_size * volume_ratio / 10000;
    dynamic_lot = dynamic_lot * martingale_multiplier;
    
    let max_affordable = account.cash / market.price;
    if dynamic_lot > max_affordable {
        dynamic_lot = max_affordable;
    }
    if dynamic_lot < 100 {
        dynamic_lot = 100;
    }
    
    let vwap_price = market.vwap;
    if vwap_price == 0 {
        vwap_price = market.price;
    }
    
    let spread = market.ask_price_0 - market.bid_price_0;
    let buy_price = vwap_price - spread * 25 / 100;
    
    if account.cash > buy_price * dynamic_lot {
        orders.submit_limit_buy(buy_price, dynamic_lot);
    }
    
    last_trade_avg_cost = account.avg_cost;
    if account.stock > 0 {
        let unrealized = (market.price - last_trade_avg_cost) * account.stock;
        if unrealized > 0 {
            last_trade_profit = 1;
        } else {
            last_trade_profit = 0;
        }
    }
}
let initialized = false;
let base_lot = 0;
let current_lot = 0;
let last_trade_loss = false;
let last_realized = 0;
let trades_today = 0;
let max_trades = 0;
let buy_back_price = 0;
let sell_pushed = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_realized = account.realized_pnl;
        
        let risk_percent = rng.rand_int(30, 50);
        let cash_to_risk = account.cash * risk_percent / 100;
        
        if market.price > 0 {
            base_lot = cash_to_risk / market.price;
        } else {
            base_lot = 100;
        }
        
        if base_lot < 100 { base_lot = 100; }
        
        current_lot = base_lot;
        max_trades = rng.rand_int(3, 8);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let realized_change = account.realized_pnl - last_realized;
    last_realized = account.realized_pnl;
    
    if realized_change < 0 {
        last_trade_loss = true;
    } else if realized_change > 0 {
        last_trade_loss = false;
    }
    
    if last_trade_loss {
        current_lot = current_lot * 2;
    } else {
        current_lot = base_lot;
    }
    
    if current_lot > account.cash / market.price && account.cash > 0 && market.price > 0 {
        current_lot = account.cash / market.price;
        if current_lot < 100 { current_lot = 100; }
    }
    
    let total_sell_pressure = 0;
    let pressure_levels = 0;
    
    if market.ask_price_0 > 0 && market.ask_price_0 < market.price && market.ask_price_0 > market.price * 99 / 100 {
        total_sell_pressure += market.ask_vol_0;
        pressure_levels += 1;
    }
    if market.ask_price_1 > 0 && market.ask_price_1 < market.price && market.ask_price_1 > market.price * 99 / 100 {
        total_sell_pressure += market.ask_vol_1;
        pressure_levels += 1;
    }
    if market.ask_price_2 > 0 && market.ask_price_2 < market.price && market.ask_price_2 > market.price * 99 / 100 {
        total_sell_pressure += market.ask_vol_2;
        pressure_levels += 1;
    }
    
    let trigger = current_lot * 3;
    
    if !sell_pushed && pressure_levels >= 2 && total_sell_pressure >= trigger && trades_today < max_trades {
        if account.stock >= current_lot {
            orders.submit_market_sell(current_lot);
            sell_pushed = true;
            buy_back_price = market.price * 98 / 100;
            if buy_back_price <= 0 { buy_back_price = 1; }
            trades_today += 1;
        }
    }
    
    if sell_pushed && market.price <= buy_back_price {
        if account.cash >= buy_back_price * current_lot {
            orders.submit_limit_buy(buy_back_price, current_lot);
            sell_pushed = false;
        }
    }
    
    if sell_pushed && market.tick % 10 == 0 {
        buy_back_price = buy_back_price * 99 / 100;
        if buy_back_price <= 0 { buy_back_price = 1; }
    }
}
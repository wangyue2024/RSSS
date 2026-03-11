let initialized = false;
let last_rebalance_tick = 0;
let lot_size = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        last_rebalance_tick = market.tick;
        lot_size = rng.rand_int(500, 5000);
    }
    
    // Cancel orders older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Rebalance every 10 ticks
    if market.tick - last_rebalance_tick >= 10 {
        last_rebalance_tick = market.tick;
        
        let price = market.price;
        let cash = account.cash;
        let stock = account.stock;
        
        if price == 0 { return; }
        
        let stock_value = stock * price;
        let total_equity = cash + stock_value;
        
        if total_equity == 0 { return; }
        
        // Calculate current stock allocation percentage (in basis points)
        let stock_pct = stock_value * 10000 / total_equity;
        
        // Calculate target trade value (50% of equity)
        let target_stock_value = total_equity * 5000 / 10000;
        
        if stock_pct > 5500 {
            // Sell: stock > 55%
            let value_to_sell = stock_value - target_stock_value;
            let shares_to_sell = value_to_sell / price;
            
            if shares_to_sell > 0 {
                // Risk-seeking: cap at 50% of current stock
                let max_sell = stock * 5000 / 10000;
                if shares_to_sell > max_sell {
                    shares_to_sell = max_sell;
                }
                
                // Ensure minimum trade size
                if shares_to_sell < lot_size {
                    shares_to_sell = lot_size;
                }
                
                if shares_to_sell > stock {
                    shares_to_sell = stock;
                }
                
                if shares_to_sell > 0 {
                    // Round to nearest dollar (1,000,000 micros)
                    let round_price = ((price + 500_000) / 1_000_000) * 1_000_000;
                    orders.submit_limit_sell(round_price, shares_to_sell);
                }
            }
        } else if stock_pct < 4500 {
            // Buy: stock < 45%
            let value_to_buy = target_stock_value - stock_value;
            let shares_to_buy = value_to_buy / price;
            
            if shares_to_buy > 0 {
                // Risk-seeking: cap at 50% of cash
                let max_buy = (cash * 5000 / 10000) / price;
                if shares_to_buy > max_buy {
                    shares_to_buy = max_buy;
                }
                
                // Ensure minimum trade size
                if shares_to_buy < lot_size {
                    shares_to_buy = lot_size;
                }
                
                if shares_to_buy > 0 {
                    // Round to nearest dollar (1,000,000 micros)
                    let round_price = ((price + 500_000) / 1_000_000) * 1_000_000;
                    orders.submit_limit_buy(round_price, shares_to_buy);
                }
            }
        }
    }
}
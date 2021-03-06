module Math  
  module GreekCalculations
    def iv(opts)
      opts.requires_keys_are_present(:option_price)
      return nil if opts[:option_price].nil?
      return nil if opts[:option_price] <= 0
      
      opts.requires_keys_are_not_nil(:stock_price, :option_strike, :option_expires_pct_year, :option_expires_pct_year_sqrt, :federal_reserve_interest_rate_f, :stock_dividend_rate_f, :option_type, :option_price, :rate_vs_expires, :price_vs_rate_vs_expires, :strike_vs_fed_vs_expires, :price_ratio_log_less_rates)
      
      iv_calc(
        opts[:stock_price], 
        opts[:option_strike], 
        opts[:option_expires_pct_year], 
        opts[:option_expires_pct_year_sqrt],
        opts[:federal_reserve_interest_rate_f], 
        opts[:stock_dividend_rate_f], 
        opts[:option_type], 
        opts[:option_price],
        opts[:price_vs_rate_vs_expires],
        opts[:price_ratio_log_less_rates],
        opts[:strike_vs_fed_vs_expires]
      )
    end
    
    
    def iv_vega(stock_price, option_strike, option_expires_pct_year, option_expires_pct_year_sqrt, volatility_guess, federal_reserve_interest_rate_f, stock_dividend_rate_f, price_ratio_log_less_rates, price_vs_rate_vs_expires)
    	var_d1 = (price_ratio_log_less_rates + volatility_guess * volatility_guess * option_expires_pct_year / 2) / (volatility_guess * option_expires_pct_year_sqrt)
    	var_nd = Math.exp(-var_d1 * var_d1 / 2) / Math::sqrt(2 * Math::PI)
    	return price_vs_rate_vs_expires * option_expires_pct_year_sqrt * var_nd
    end


    def iv_option_price(stock_price, option_strike, option_expires_pct_year, option_expires_pct_year_sqrt, volatility_guess, federal_reserve_interest_rate_f, stock_dividend_rate_f, option_type, price_ratio_log_less_rates, price_vs_rate_vs_expires, strike_vs_fed_vs_expires)
    	var_d1                       = (price_ratio_log_less_rates + volatility_guess * volatility_guess * option_expires_pct_year / 2) / (volatility_guess * option_expires_pct_year_sqrt)
    	var_d2                       = var_d1 - volatility_guess * option_expires_pct_year_sqrt
      
      case option_type
      when :call
    		return price_vs_rate_vs_expires * normal_distribution(var_d1) - strike_vs_fed_vs_expires * normal_distribution(var_d2)
      when :put
    		return strike_vs_fed_vs_expires * normal_distribution(-var_d2) - price_vs_rate_vs_expires * normal_distribution(-var_d1)
      else
        raise "Invalid option_type = #{option_type.inspect}"
      end
    end
    
    
    def iv_volatility_guess0(stock_price, option_strike, option_expires_pct_year, federal_reserve_interest_rate_f, stock_dividend_rate_f)
      Math.sqrt(
      (Math.log(stock_price / option_strike) + (federal_reserve_interest_rate_f - stock_dividend_rate_f) * option_expires_pct_year).abs * 2 / option_expires_pct_year)
    end
    
    
    def iv_calc(stock_price, option_strike, option_expires_pct_year, option_expires_pct_year_sqrt, federal_reserve_interest_rate_f, stock_dividend_rate_f, option_type, option_price, price_vs_rate_vs_expires, price_ratio_log_less_rates, strike_vs_fed_vs_expires)
      # Contstant values for the calculations
    	price_limit = [0.005, 0.01 * option_price].min

      # Lambda for short-hand calculations
      calc_option_price            = lambda { |volatility_guess| iv_option_price(stock_price, option_strike, option_expires_pct_year, option_expires_pct_year_sqrt, volatility_guess, federal_reserve_interest_rate_f, stock_dividend_rate_f, option_type, price_ratio_log_less_rates, price_vs_rate_vs_expires, strike_vs_fed_vs_expires) } 
      
      # Lambda for short-hand calculations
      calc_vega                    = lambda { |volatility_guess| iv_vega(stock_price, option_strike, option_expires_pct_year, option_expires_pct_year_sqrt, volatility_guess, federal_reserve_interest_rate_f, stock_dividend_rate_f, price_ratio_log_less_rates, price_vs_rate_vs_expires) }
      
      # Lambda for short-hand calculations
      calc_volatility_guess1       = lambda { |var_volatility_guess, var_option_price, var_vega| var_volatility_guess - (var_option_price - option_price) / var_vega }
      
      # Lambda for short-hand calculations
      is_terminal_volatility_guess = lambda { |var_option_price| ((option_price - var_option_price).abs < price_limit) }

      # Lambda for short-hand calculations
      cleanup_volatility_guess     = lambda { |volatility_guess| volatility_guess.nil? || volatility_guess <= 0 ? nil : volatility_guess.to_f }
      
    	var_volatility_guess = iv_volatility_guess0(stock_price, option_strike, option_expires_pct_year, federal_reserve_interest_rate_f, stock_dividend_rate_f)
      var_volatility_guess = 0.1 if var_volatility_guess <= 0
    	var_option_price     = calc_option_price.call(var_volatility_guess)

      if is_terminal_volatility_guess.call(var_option_price)
        return cleanup_volatility_guess.call(var_volatility_guess)
      end

    	var_vega = calc_vega.call(var_volatility_guess)

    	var_volatility_guess1 = calc_volatility_guess1.call(var_volatility_guess, var_option_price, var_vega)

    	var_step = 1
      max_steps = 13
    	while ((var_volatility_guess - var_volatility_guess1).abs > 0.0001 && var_step < max_steps)
    		var_volatility_guess = var_volatility_guess1
    		var_option_price = calc_option_price.call(var_volatility_guess)

    		if is_terminal_volatility_guess.call(var_option_price)
          return cleanup_volatility_guess.call(var_volatility_guess)
        end

    		var_vega = calc_vega.call(var_volatility_guess)

    		var_volatility_guess1 = calc_volatility_guess1.call(var_volatility_guess, var_option_price, var_vega)
    		if (var_volatility_guess1 < 0)
          return cleanup_volatility_guess.call(var_volatility_guess1)
        end

    		var_step += 1
      end

    	if (var_step < max_steps)
        return cleanup_volatility_guess.call(var_volatility_guess1)
      end

      var_option_price = calc_option_price.call(var_volatility_guess1)

    	if is_terminal_volatility_guess.call(var_option_price)
        return cleanup_volatility_guess.call(var_volatility_guess1)
    	else
    		return nil
      end
    end
    
  end
end

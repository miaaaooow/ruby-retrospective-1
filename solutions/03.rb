require 'bigdecimal'
require 'bigdecimal/util'

class Inventory
  attr_reader :items, :coupons

  def initialize
    @items = []
    @coupons = []
  end
  
  def register(name, price, promotion = nil)
    price_num = BigDecimal(price)
    if price_num < 0.01 or price_num > 999.99  or name.length > 40 
      raise "Invalid parameters passed."
    elsif @items.select { |item| item.name == name }.size > 0
      raise "Duplicate item registered."
    else
      @items << StockItem.new(name, price_num, promotion)
    end
  end

  def register_coupon(coupon_name, coupon_details)
    if registered_coupon(coupon_name)
      raise "Duplicate coupon registration."
    elsif coupon_details[:percent]
      @coupons << PercentCoupon.new(coupon_name, coupon_details[:percent])
    elsif coupon_details[:amount]
      @coupons << AmountCoupon.new(coupon_name, coupon_details[:amount])
    else
      raise "Unsupported type of coupon."      
    end
  end

  def registered_coupon(coupon_name)
    coupon = @coupons.select { |cupon| cupon.name == coupon_name }
    if coupon.size == 0
      nil
    else
      coupon[0]
    end
  end
  
  def new_cart
    Cart.new(self)
  end

  def get_item_with_name(name) 
    item = @items.select { |item| item.name == name }
    if item == []
      nil
    else
      item[0]
    end
  end
end


class Cart
  attr_reader :items, :coupon

  def initialize(inventory) 
    @items = {}
    @inventory = inventory
    @coupon = nil
  end

  # Adds an item/quantity to a cart
  def add(name, quantity = 1)
    item = @inventory.get_item_with_name(name)
    if quantity < 0 or quantity > 99
      raise "Too large or too small number of items requested."
    elsif item and not @items[item]
      @items[item] = quantity
    elsif item and @items[item]
      @items[item] += quantity
    else
      raise "The requested item is not in the inventory."
    end
  end

  # Defines the usage of a coupon
  def use(coupon_name)
    coupon = @inventory.registered_coupon(coupon_name)
    if coupon 
      @coupon ||= coupon
    else
      raise "Coupon not registered."
    end
  end


  # Totals the price amount in the cart
  def total
    positive = @items.map { |item, qty| item.price * qty }.reduce(:+)
    negative = @items.select { |item, qty| item.promotion }
                     .map { |item, qty| item.promotion.apply_for_n(qty, item.price) }
                     .reduce(:+)
    negative = 0 if negative == nil
    coupon = 0
    coupon = @coupon.apply_to_total(positive + negative) if @coupon
    positive + negative + coupon
  end
  
  def invoice
    InvoiceFormatter.new(self, @inventory).invoice
  end

end  


class StockItem
  attr_accessor :name, :price, :promotion
  
  def initialize(name, price, promotion)
    @price = price
    @name  = name
    @promotion = StockItem.extract_promotion(promotion)
  end

  def self.extract_promotion(promotion)
    if not promotion
      nil
    elsif promotion[:get_one_free]
      @promotion = OneFreePromotion.new(promotion[:get_one_free])
    elsif promotion[:package]
      @promotion = NPacketPromotion.new(promotion[:package])
    elsif promotion[:threshold]
      @promotion = AfterNthPromotion.new(promotion[:threshold])
    else
      raise "Invalid promotion type."
    end  
  end
end


class PercentCoupon
  attr_reader :name, :percent, :value
  
  def initialize(name, percent)
    @name = name
    @percent = percent
    @value
  end

  def to_s
    "#{@name} - #{@percent}% off"
  end

  def apply_to_total(total)
    @value = - @percent * total / 100
    @value
  end
end


class AmountCoupon 
  attr_reader :name, :amount, :value
  
  def initialize(name, amount)
    @name = name
    @amount = amount
    @value = 0
  end

  def to_s
    @name + " - " + InvoiceFormatter.format_big_d(@amount) + " off" 
  end

  def apply_to_total(total)
    if (total < @amount)
      @value = - total
    else
      @value = - @amount
    end
    @value
  end
end


class OneFreePromotion
  def initialize(n)
    @n = n
  end

  def to_s
    "(buy " + (@n - 1).to_s + ", get 1 free)"
  end

  def apply_for_n(number_of_items, price)
    -price * (number_of_items / @n)
  end
end


class NPacketPromotion
  def initialize(parameters)
    @n = parameters.keys[0]
    @percent = parameters[@n]
  end

  def to_s
    "(get " + @percent.to_s + "% off for every " + @n.to_s + ")"
  end

  def apply_for_n(number_of_items, price)
    items_in_promotion = (number_of_items / @n) * @n
    -price * @percent * items_in_promotion / 100     
  end
end


class AfterNthPromotion
  def initialize(parameters)
    @n = parameters.keys[0]
    @percent = parameters[@n]
  end

  def to_s
    "(" + @percent.to_s + "% off of every after the " + format_num(@n) + ")"
  end

  def apply_for_n(number_of_items, price)
    if (number_of_items < @n)
      0
    else
      -price * @percent * (number_of_items - @n) / 100
    end
  end

  def format_num(n)
    if n % 10 == 1
      n.to_s + "st"
    elsif n % 10 == 2
      n.to_s + "nd"
    elsif n % 100 == 3
      n.to_s + "rd"
    else
      n.to_s + "th"
    end
  end
end

class InvoiceFormatter  
  @@line_length  = 50
  @@line2_length = 10
 
  def initialize(cart, inventory)
    @cart = cart
    @inventory = inventory
  end

  def invoice
    limit = "+" << "-" * (@@line_length - 2) << "+" << "-" * @@line2_length << "+" << "\n"
    invoice_header = limit + format_header() + limit
    invoice_items  = @cart.items.map { |item, qty| format_lines(item, qty) }.join("")
    total = format_total InvoiceFormatter.format_big_d(@cart.total)
    invoice_coupon = ""
    invoice_coupon = format_coupon(@cart.coupon) if @cart.coupon

    invoice_total  = limit + total  + limit
    invoice_header + invoice_items + invoice_coupon + invoice_total
  end

  def self.format_big_d(big_decimal) 
    "%5.2f" % big_decimal.to_f 
  end 
 
  private 
  def format_lines(item, qty)
    line = format_item item.name, qty.to_s,InvoiceFormatter.format_big_d(item.price * qty)
    if item.promotion
      line << format_promotion(item.promotion, item.promotion.apply_for_n(qty,item.price))
    end
    line
  end

  def format_header
    format_item "Name", "qty", "price"
  end

  def format_total(total)
    format_item "TOTAL", "", total.to_s
  end

  def format_item(left, right, rightest)
    left_ws     = @@line_length  - 4 - left.length - right.length
    rightest_ws = @@line2_length - 1 - rightest.length
    "| " + left + " " * left_ws + right +  " |" + " " * rightest_ws + rightest + " |\n"
  end

  def format_coupon(coupon)
    amount = InvoiceFormatter.format_big_d coupon.value
    format_item "Coupon " + coupon.to_s, "", amount
  end

  def format_promotion(promotion, value)
    format_item "  " + promotion.to_s, "", InvoiceFormatter.format_big_d(value)
  end
end


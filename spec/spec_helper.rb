$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'stokla'

Stokla.configure do |c|
  c.dbname = 'foobar'
end
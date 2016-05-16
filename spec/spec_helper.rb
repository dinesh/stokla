$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pg-queue'

PGQueue.configure do |c|
  c.dbname = 'foobar'
end
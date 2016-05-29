require 'logger'
require_relative "stokla/version"
require_relative "stokla/pool"

module Stokla
  class << self
    attr_accessor :logger, :log_level, :delete_item, :_pool
    attr_accessor :schema, :table_name

    DEFAULT_OPTS = { schema: 'public', table_name: 'jobs', log_level: Logger::INFO }

    def configure(options={})
      if block_given?
        DEFAULT_OPTS.each {|k,v| self.send("#{k}=", v) }
        yield(self)
      else
        DEFAULT_OPTS.merge(options).each {|k,v| self.send("#{k}=", v) }
      end
    end

    def pending
      Queue.pending
    end

    def logger
      @logger ||= 
        if defined?(Rails)
          Rails.logger
        else
          logger = Logger.new(STDOUT, log_level: self.log_level)
          logger.progname = 'Stokla'
          logger
        end
    end

    def pool
      self._pool.tap{|p| raise "Stokla.pool is not set." unless p }
    end

    def pool=(apool)
      self._pool = 
        case apool.class.to_s
        when 'ActiveRecord::ConnectionAdapters::ConnectionPool'
          Adapter::ActiveRecord.new(apool)
        when "Sequel::Postgres::Database"
          Adapter::Sequel.new(apool)
        when "ConnectionPool"
          Adapter::ConnectionPool.new(apool)
        when "Pond"
          Adapter::Pond.new(apool)
        else
          if ENV['RACK_ENV'] == 'test'
            apool
          else
            raise "Usupported pool type: #{apool.to_s}"
          end
        end
    end
  end
end

require_relative 'stokla/queue'
require_relative 'stokla/job'

require 'pg'
require 'pond'
require 'logger'
require_relative "stokla/version"

module Stokla
  class << self
    attr_accessor :logger, :log_level, :delete_item
    attr_accessor :schema, :dbname, :table_name, :username, :password, :port, :pool_size

    DEFAULT_OPTS = { schema: 'public', table_name: 'jobs', pool_size: 5, log_level: Logger::INFO }

    def configure(options={})
      if block_given?
        DEFAULT_OPTS.each {|k,v| self.send("#{k}=", v) }
        yield(self)
      else
        DEFAULT_OPTS.merge(options).each {|k,v| self.send("#{k}=", v) }
      end
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
      @pool ||= Pond.new(maximum_size: self.pool_size) do
          PG.connect(
            dbname:   self.dbname,
            user:     self.username,
            password: self.password,
            port:     self.port
          )
      end
    end
  end
end

require_relative 'stokla/queue'
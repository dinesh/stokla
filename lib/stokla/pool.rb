
module Stokla
  module Adapter
    class Base
      attr_accessor :underlying
      def initialize(underlying)
        @underlying = underlying
      end

      def checkout
        raise NotImplemented, "should be implemented in derived class"
      end

      def get(object_id)
        raise NotImplemented
      end
    end

    class ActiveRecord < Base
      def checkout
        underlying.with_connection do |conn|
          yield conn.raw_connection
        end
      end

      def get(conn_id)
        conn = underlying.instance_variable_get(:@connections).find{|t| t.raw_connection.object_id == conn_id }
        conn.try(:raw_connection)
      end
    end

    class Sequel < Base
      def checkout(&block)
        underlying.synchronize(&block)
      end

      def get(conn_id)
        underlying.pool.available_connections.find{|t| t.object_id == conn_id }
      end
    end

    class ConnectionPool < Base
      def checkout(&block)
        underlying.with(&block)
      end

      def get(conn_id)
        underlying.instance_variable_get(:@available).instance_variable_get(:@que).find{|t| t.object_id == conn_id }
      end
    end

    class Pond < Base
      def checkout(&block)
        underlying.checkout(&block)
      end

      def get(conn_id)
        underlying.available.find{|t| t.object_id == conn_id }
      end
    end
  end
end
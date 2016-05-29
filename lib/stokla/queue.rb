require 'yaml'
require_relative "sql"

module Stokla
  class LockedItem < Struct.new(:item, :lock); end
  class QueueItem < Struct.new(:id, :name, :priority, :data); end

  class Queue
    include SQL
    attr_reader :queue_name
    
    def initialize(name, options={})
      @qlocks = []
      @mutex = Mutex.new
      @queue_name = name
    end

    def enqueue(item, priority=1)
      if item
        ensure_table
        data = YAML::dump(item)
        insert_item(queue_name, data, priority)
      end
    end

    def take
      locking_item = locking_take
      if block_given? && locking_item
        begin
          yield(locking_item)
          delete(locking_item)
        rescue => e
          Stokla.logger.warn("Got exception while processing item: #{locking_item.item.id}. Will try again.")
          unlock_item(locking_item)
        end
      else
        locking_item
      end
    end

    def delete(locked_item)
      delete_item(locked_item)
      unlock_item(locked_item)
    end

    def unlock_item(item)
      qlock = nil
      sync { qlock = @qlocks.find{|t| t[:lock_id] == item.lock[1] } }

      connection_for_lock(qlock[:conn_id]) do |connection|
        execute(
          sql_statement(:unlock_lock),
          item.lock[0],
          item.lock[1],
          connection: connection
        )
      end

      sync { @qlocks.delete(qlock) }
    end

    def delete_item(locking_item)
      item_id = locking_item.item.id

      if Stokla.delete_item
        execute("DELETE FROM #{quoted_table_name} WHERE id = $1", item_id)
      else
        execute("UPDATE #{quoted_table_name} SET deleted = true WHERE id = $1", item_id)
      end
    end

    private

    def locking_take
      table_oid = db_table_oid

      with_conn do |connection|
        qlocks, qlock_not_in, statement = nil
        
        sync {
          qlocks       = @qlocks.select{|l| l[:conn_id] == connection.object_id }.map{|t| t[:lock_id] }.compact
          qlock_not_in = qlocks.size > 0 ? "AND id NOT IN (#{qlocks.join(',')})"  : ""
          statement = sql_statement(:lock_job).gsub(/_qlocks_not_in/, qlock_not_in)
        }

        if record = connection.exec_params(statement, [table_oid, queue_name]).first
          add_thread_lock(record['id'], connection.object_id)
          record['data'] = YAML::load(record['data'])
          item = QueueItem.new(record['id'], record['name'], record['priority'], record['data'])
          Stokla.logger.debug "#{connection.object_id} took job:#{record['id']} with payload: #{record['data']}"
          LockedItem.new(item, [table_oid, item.id])
        end
      end
    end

    def clear_locks
      sql    = %{SELECT classid, objid from pg_locks where classid = $1 and locktype = 'advisory'}
      qlocks = execute(sql, db_table_oid)
      sql    = sql_statement(:select_lock)

      locks.values.each{|r| execute(sql, r[0], queue_name) }
    end

    def add_thread_lock(record_id, conn_object_id)
      sync do
        @qlocks << { lock_id: record_id, conn_id: conn_object_id }
      end
    end

    def sync
      @mutex.synchronize { yield }
    end

    def self.pending
      Stokla.pool.checkout do |conn|
        sql = SQL::STATEMENTS[:count_items].gsub(/_table_name_/, Stokla.table_name)
        conn.exec(sql).first['total'].to_i
      end
    end
  end
end
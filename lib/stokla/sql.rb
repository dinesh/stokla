
module Stokla
  module SQL
    STATEMENTS = {
      :lock_job => %{
        WITH RECURSIVE queued AS (
          SELECT (q).*, pg_try_advisory_lock($1, cast((q).id as int)) AS locked
          FROM (
            SELECT q 
            FROM _table_name_ as q 
            WHERE q.name = $2
            AND deleted IS FALSE 
            AND retries < $3
            ORDER BY priority, id 
            LIMIT 1
          ) AS t1
          UNION ALL (
            SELECT (q).*, pg_try_advisory_lock($1, cast((q).id as int)) AS locked
            FROM (
              SELECT (
                SELECT q 
                FROM _table_name_ as q 
                WHERE q.name = $2
                AND deleted IS FALSE 
                AND retries < $3 _qlocks_not_in
                AND (priority, id) > (queued.priority, queued.id)
                ORDER BY priority, id LIMIT 1
              ) as q 
              FROM queued
              WHERE queued.id IS NOT NULL
              LIMIT 1
            ) AS t1
          )
        )
        SELECT id, name, priority, data, deleted FROM queued WHERE locked _qlocks_not_in LIMIT 1
      }.freeze,

      :get_table_oid => %{
        SELECT c.oid AS table_oid
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n
             ON n.oid = c.relnamespace
        WHERE n.nspname = $1
          AND c.relname = $2
      }.freeze,

      :check_table => %{ SELECT 1 FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace 
        WHERE n.nspname = $1 AND c.relname = $2
      }.freeze,

      :create_table => %{
        CREATE TABLE _table_name_ (
          id bigserial,
          name text NOT NULL,
          priority integer NOT NULL DEFAULT 100,
          data text,
          retries integer DEFAULT 0,
          error text,
          deleted boolean NOT NULL DEFAULT false,
          constraint  pg_queue_pkey 
            primary key (name, priority, id, deleted)
        );
      }.freeze,

      :insert_item => "INSERT INTO _table_name_ (name, data, priority) values ($1, $2, $3)".freeze,
      
      :unlock_lock => "SELECT pg_advisory_unlock(cast($1 as int), cast($2 as int)) as unlocked".freeze,
      
      :select_lock => %{
        SELECT pg_advisory_unlock(cast($1 as int), cast(q.id as int)) 
        FROM _table_name_ AS q 
        WHERE name = $2
      }.freeze,

      :count_items => %{SELECT count(*) AS total from _table_name_ where deleted IS FALSE}.freeze,

      :on_error => %{UPDATE _table_name_ SET retries=retries+1,error=$2 WHERE id=$1}.freeze
    }

    def sql_statement(task, options={})
      STATEMENTS[task].gsub(/_table_name_/, quoted_table_name)
    end

    def connection_for_lock(conn_object_id)
      conn = Stokla.pool.get(conn_object_id)
      raise "Unable to find connection for by object_id: #{conn_object_id}" unless conn

      yield(conn) if block_given?
      conn
    end

    def delete_queue
      execute("DELETE FROM #{quoted_table_name} where name = $1", queue_name)
    end

    def execute sql, *params, connection: nil, debug: true
      if connection
        puts "#{connection.object_id}(#{!connection.finished?}): #{sql} #{params.inspect}" if debug
        connection.exec_params(sql, params)
      else
        with_conn do |c| 
          puts "#{c.object_id}: #{sql} #{params.inspect}" if debug
          c.exec_params(sql, params)
        end
      end
    end

     def quoted_table_name
      [qt(schema), qt(table_name)].join('.')
    end

    def qt(str)
      with_conn{|c| c.quote_ident(str) }
    end

    def table_exists?
      execute(sql_statement(:check_table), schema, table_name).values.size > 0
    end

    def insert_item(qname, data, priority)
      execute(sql_statement(:insert_item), qname, data, priority)
    end

    def ensure_table
      create_table! unless table_exists?
    end

    def db_table_oid
      execute(sql_statement(:get_table_oid), schema, table_name, debug: false).first['table_oid']
    end

    def create_table!
      execute(sql_statement(:create_table))
    end

    def table_name
      Stokla.table_name
    end

    def schema
      Stokla.schema
    end

    def with_conn(&block)
      Stokla.pool.checkout(&block)
    end
  end
end
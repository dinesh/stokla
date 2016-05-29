
module Stokla
  class Job
    @queue_name = 'jobs'
    @priority   = 10

    def initialize(*args)
      @args = args
    end

    def run(*args); end

    def enqueue
      data = {
        :klass_name => self.class.name,
        :args => @args
      }
      self.class.queue.enqueue(data, self.class.priority)
    end

    class << self
      attr_accessor :queue_name, :priority

      def inherited(base)
        base.instance_variable_set(:@queue_name, queue_name)
        base.instance_variable_set(:@priority, priority)        
      end

      def pending
        Stokla.pending
      end
      
      def queue
        @queue ||= Queue.new(queue_name)
      end

      def work
        if work = queue.take
          klass_name = work.item.data[:klass_name]
          args  = work.item.data[:args]

          if klass_name && args
            begin
              job = Kernel.const_get(klass_name).new
              job.run(*args)
              queue.delete_item(work)
            rescue => e
              Stokla.logger.error "Got error #{e} in #{klass_name}, will retry."
            ensure
              queue.unlock_item(work)
            end
          end
        end
      end
    end
  end
end
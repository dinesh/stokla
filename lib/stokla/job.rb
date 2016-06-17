
module Stokla
  class Job
    @queue_name = 'jobs'
    @priority   = 10

    def initialize(*args)
      @args = args
    end

    def run(*args); end

    def logger
      Stokla.logger
    end

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
      
      def queue
        @queue ||= Queue.new(queue_name)
      end

      def work
        if work = queue.take
          klass_name = work.item.data[:klass_name]
          args       = work.item.data[:args]

          if klass_name && args
            begin
              job = constantize(klass_name).new
              job.run(*args)
              queue.delete_item(work)
            rescue => error
              queue.on_error(work.item.id, error)
              logger.error "Got error #{error} in #{klass_name}, will retry."
            ensure
              queue.unlock_item(work)
            end
          end
        end
      end

      private

      def constantize(class_name)
        return unless class_name
        return class_name if class_name.is_a?(Class)
        constant = Object
        class_name.split('::').each do |name|
          constant = constant.const_get(name) || constant.const_missing(name)
        end
        constant
      end
    end
  end
end
module Stokla
  class RakeTasks
    include Rake::DSL if defined?(Rake::DSL)

    def install_tasks
      namespace :stokla do
        desc "Process jobs using background workers"
        task :work do
          $stdout.sync = true
          Rails.application.eager_load! if defined?(::Rails) && Rails.respond_to?(:application)
          Stokla.logger.level  = Logger.const_get((ENV['STOKLA_LOG_LEVEL'] || 'INFO').upcase)
          stop = false

          %w( INT TERM ).each do |signal|
            trap(signal) { stop = true }
          end
          
          loop do
            sleep 0.01
            Stokla::Job.work
            break if stop
          end
        end

        desc "Drop job table"
        task :drop do
          Stokla.drop
        end

        desc "Clear job table"
        task :clear do
          Stokla.clear!
        end   
      end
    end
  end
end

Stokla::RakeTasks.new.install_tasks
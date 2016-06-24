# Stokla

`stokla` is a queue for Ruby and PostgreSQL that manages jobs using advisory locks, which gives it several advantages over other RDBMS-backed queues. 

It is designed to have better performance and reliable than [DelayedJob](https://github.com/collectiveidea/delayed_job). Workers don't block each other when trying to lock jobs, as often occurs with row level locking. This allows for very high throughput with a large number of workers. 

## Installation

Add this line to your application's Gemfile:

```
gem 'stokla'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install stokla

## Usage

#### Setup & Configuration

You can configure `Stokla` using

```
Stokla.configure do |config|
  config.pool                       # type of pool (activerecord, pond, connection_pool, sequel pool )
  config.schema                     # name of postgres schema ('public' by default)
  config.table_name                 # name of postgres jobs table ('jobs' by default )
  config.logger                     # logger instance
  config.delete_after_completion    # delete the work item after completion ( false by default )
  config.max_attempts               # number of times to retry in case of error ( 10 by default )
end

```

It supports several popular database pools like activerecord, sequel, pond and connection_pool. 

#### Adding Job

To create a queue and enqueue a work item -

```
queue = Stokla::Queue.new('mailer')
queue.enqueue({user_id: 1, subject: 'Welcome'})
```

#### Consume Job

To consume a work item into another thread or process -

```
work = queue.take
if work
  payload = work.item.data
  @user = User.find payload[:user_id]
  UserMailer.welcome_email(user: @user, subject: payload[:subject]).deliver_now
end

## afterwards delete the job from the queue
queue.delete(work)

```

You can also provide an block to process a work item ( It will automatically delete the item from the queue after successfull completion ) 

```
queue.take do |work|
  payload = work.item.data
  @user = User.find payload[:user_id]
  UserMailer.welcome_email(user: @user, subject: payload[:subject]).deliver_now
end
```

You can also define your task by inheriting `Stokla::Job` which should override `run` method -

```
class HelloTask < Stokla::Job

  # You can optionally set queue_name and priority like
  # @queue_name = 'hello'
  # @priority   = 10
  
  def run(msg)
    puts "Hello #{msg} from work"
  end
end

```

You can just run following code to ingest a work -

    HelloTask.new('world').enqueue
  

You can also optionally set `queue_name`(name of queue) and `priority`. Jobs with lower priority will be processed faster than higher ones. By default all of the jobs will have priority as 100. 

Stokla also provides a background worker as a rake task. You can include rake task into your `Rakefile` and run following command -

    require 'stokla/rake'

    rake stokla:work    # to process jobs using background workers" 
    rake stokla:drop    # to drop job table
    rake stokla:clear   # to clear job table

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/dinesh/stokla. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


# PGQueue

`pg-queue` is a queue for Ruby and PostgreSQL that manages jobs using advisory locks, which gives it several advantages over other RDBMS-backed queues. 

It is designed to have better performance and reliable than [DelayedJob](https://github.com/collectiveidea/delayed_job). Workers don't block each other when trying to lock jobs, as often occurs with row level locking. This allows for very high throughput with a large number of workers. 

## Installation

Add this line to your application's Gemfile:

```
gem 'pg-queue'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pg-queue

## Usage

You can configure `PGQueue` using `configure` block -

```
PGQueue.configure do |config|
  config.dbname = 'test'
  config.username = '...'
  config.password = '...'
  
  
  config.schema = 'public'      # name of postgres schema 
  config.table_name = 'jobs'    # name of postgres table
end
```

To create a queue -

```
queue = PGQueue::Queue.new('mailer')
queue.enqueue({user_id: 1, subject: 'Welcome'})
```

To consume a job item into another thread or process -

```
work = queue.take
if work
  payload = work.item.data
  @user = User.find payload[:user_id]
  UserMailer.welcome_email(user: @user, subject: payload[:subject]).deliver_now
end

## afterward delete the job from the queue
queue.delete(work)

```

You can also provide an block to process job 

```
queue.take do |work|
  payload = work.item.data
  @user = User.find payload[:user_id]
  UserMailer.welcome_email(user: @user, subject: payload[:subject]).deliver_now
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/pg-queue. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).


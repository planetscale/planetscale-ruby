# PSDB Ruby Client

This Gem provides an easy to use client for connecting your Ruby application to PSDB. It handles setting up a local proxy that allows you to connect to any PSDB database and branch without reconfiguration, so that you can easily swap and choose using only environment variables.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'psdb'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install psdb

## Usage

### Configuration

This Gem exposes one class, PSDB::Proxy, which can be configured from the environment, or with a hash on initialization. The current configuration options are as follows:

```
@token_name = kwargs[:token_id] || ENV['PSDB_TOKEN_NAME']
@token = kwargs[:token] || ENV['PSDB_TOKEN']
@org = kwargs[:org] || ENV['PSDB_ORG']
@db = kwargs[:db] || ENV['PSDB_DB']
@branch = kwargs[:branch] || ENV['PSDB_DB_BRANCH']
```

If your environment variables are present, simply instantiating the class:

```
proxy = PSDB::Proxy.new
```

To run the proxy process in the background, run:

```
proxy.start
```

This will fork and exec the proxy binary, restarting it if it crashes. Output will be piped back to STDOUT/STDERR for debugging purposes.

Presently, PSDB still requires you to use a database password when connecting. The proxy class also has a `database_password` method that will return the password for the current database and branch.

The user will always be `root` when connecting. 

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome. This Gem is internal to PlanetScale currently.

## License

Currently this Gem is specified under the MIT license, however it has not been made public. Care will be taken before this is done to choose an appropriate license. 

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

This Gem exposes one class, and a singleton of that for configuring a 'global' instance of the proxy. This is recommended for most users who do not need to connect to multiple databases simultaneously. There are many ways to configure the connection, for local development we recommend:

The Gem will pick up configuration created by the CLI, to point it to your database run this in the root of your Rails project:

```
~> pscale branch switch main --database <db_name>
Finding branch main on database <db_name>
Successfully switched to branch main on database <db_name>
```

Now, run the built-in generator to setup the basic configuration: `rails generate planetscale:install`

Finally, point your `database.yml` at the proxy the Gem will start, which will listen on `127.0.0.1:3305`. This will look something like:

```yaml
development:
  <<: *default
  username: root
  host: 127.0.0.1
  port: 3305
  database: <db_name>
```

Now, your Rails app will boot the proxy as the app is starting, and connect to the `main` branch on your DB. 

### Service Token Authentication

To use this Gem in 'production', we'll start by creating a PlanetScale Service Token that can connect to your database. To do this, grab the `pscale` CLI and do:

```
~> pscale org switch <org_name>

~> pscale service-token create
  NAME           TOKEN
  -------------- ------------------------------------------
  0sph6kvz5bxi   <redacted>

~> pscale service-token add-access 0sph6kvz5bxi connect_production_branch --database <db_name>
  DATABASE   ACCESSES
 ---------- ---------------------------
  testdb     connect_production_branch
```

To configure your application in production, you'll need to feed it all of the right information via environment variables:

```
PSDB_ORG=<org_name>
PSDB_DB=<db_name>
PSDB_DB_BRANCH=main
PSDB_TOKEN_NAME=0sph6kvz5bxi
PSDB_TOKEN=<redacted>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome. This Gem is internal to PlanetScale currently.

## License

Currently this Gem is specified under the MIT license, however it has not been made public. Care will be taken before this is done to choose an appropriate license. 

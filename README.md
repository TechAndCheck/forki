# forki

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/forki`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Pre Reqs

This requires the chromedriver

### MacOS

`brew install chromedriver`

### Raspberry OS (aka Rasbian / Debian)
Since this requires ARMHF support it's not through regular sources. However, the maintainers of Raspberry OS has made their own!
`sudo apt install chromium-chromedriver`

### Debian/Ubuntu
`sudo apt install chromedriver` (should work)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'forki'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install forki

### Selenium standalone

We use Selenium's standalone package. To set it up:

1. Download the "Selenium Server (Grid)" JAR package at https://www.selenium.dev/downloads/
2. Save it to the folder of this package
3. Test that it works by running `java -jar ./selenium-server-4.2.1.jar standalone --session-timeout 1000` (note the actual version you downloaded)

## Testing

1. Turn on the Selenium server `java -jar ./selenium-server-4.2.1.jar standalone --session-timeout 1000` in a separate pane or window
2. `rake test`
    
## Debugging

This scraper is prone to break pretty often due to Facebook's GraphQL schema being pretty damn unstable.
Whether this is malevolent (to purposely break scrapers) or just happening in the course of development is undetermined and really, doesn't matter.

Debugging this is a bit of a pain, but I'm laying out a few steps to start at and make this easier.
Some of this may sound basic, but it's good to keep it all in mind.

1. Run the tests `rake test` and note the line where everything is breaking. If the tests consistently fail on a single line, Facebook has likely changed the schema for a certain type of media (e.g., live videos, page photos). 
2. Set a debug point at the top of the function where the failures are occurring. Step through the the code as it extracts GraphQL objects. If you find that one of the extracted objects is `nil`, you've discovered the place where Facebook has changed its schema and which GraphQL object we no longer have access to.  
3. Find a new place to extract the Facebook post/user attributes we used to grab from the now-missing GraphQL object. Try grepping through the `graphql_strings` array to find the key of the attribute you need to grab data for.
4. Repeat step 3 for each attribute we used to draw from the GraphQL object identified in step 2.
5. Trust the tests, run them over and over, modifying as little about the rest of the code as possible,
   otherwise you may end up changing the structure of everything, we don't want that.
6. Ask Chris or Asa if you have questions.

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/forki. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/forki/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the forki project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/forki/blob/master/CODE_OF_CONDUCT.md).

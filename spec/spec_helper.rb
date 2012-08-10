require 'capybara/rspec'
require 'capybara/poltergeist'

Capybara.default_driver = :poltergeist
Capybara.run_server = false
Capybara.app_host = 'http://localhost:3000'

require 'capybara/rspec'
require 'capybara/poltergeist'

Capybara.current_driver = :poltergeist
Capybara.app_host = 'http://localhost:3000'

# frozen_string_literal: true

require 'sinatra'
require 'sinatra/subdomain'
require 'json'

users = {
  john: { first_name: 'John', last_name: 'Smith', age: 28 },
  simon: { first_name: 'Simon', last_name: 'Random', age: 26 },
  thibault: { first_name: 'Thibault', last_name: 'Denizet', age: 25 }
}

before do
  content_type 'application/json'
end

# This are the routes for version 1
subdomain :api1 do
  get '/users' do
    users.map { |name, data| data }
  end
end

# This are the routes for version 2
subdomain :api2 do
  get '/users' do
    users.map do |name, data|
      {
        full_name: "#{data[:first_name]} #{data[:last_name]}",
        age: data[:age]
      }
    end.to_json
  end
end

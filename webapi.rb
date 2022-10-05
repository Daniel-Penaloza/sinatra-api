# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'rubocop'
require 'gyoku'
require 'byebug'
require 'crack'

users = {
  'john': { first_name: 'John', last_name: 'Smith', age: 28 },
  'simon': { first_name: 'Simon', last_name: 'Random', age: 26 },
  'thibault': { first_name: 'Thibault', last_name: 'Denizet', age: 25 }
}

deleted_users = { }

helpers do
  def json_or_default?(type)
    ['application/json', 'application/*', '*/*'].include?(type.to_s)
  end

  def xml?(type)
    type.to_s == 'application/xml'
  end

  def accepted_media_type
    return 'json' unless request.accept.any?

    request.accept.each do |mt|
      return 'json' if json_or_default?(mt)
      return 'xml' if xml?(mt)
    end

    content_type 'text/plain'
    halt 406, 'application/json, application/xml'
  end

  def type
    @type ||= accepted_media_type
  end

  def send_data(data = {})
    case type
    when 'json'
      content_type 'application/json'
      data[:json].call.to_json if data[:json]
    when 'xml'
      content_type 'application/xml'
      Gyoku.xml(data[:xml].call) if data[:xml]
    end
  end

  def review_media_types(content_type)
    accepted_media_type_valid = ['application/json', 'application/xml']

    halt 415 unless accepted_media_type_valid.include?(content_type)
  end

  def find_user(request)
    user = JSON.parse(request)
    existing = users[first_name.to_sym]
    users[first_name.to_sym] = user
    status existing ? 204 : 201
  rescue JSON::ParserError => e
    halt 400, send_data(json: -> { { message: e.to_s } },
                        xml: -> { { message: e.to_s } })
  end
end

get '/' do
  'Master Ruby Web APIS'
end

# /users
options '/users' do
  response.headers['Allow'] = 'HEAD,GET,POST'
  status 200
end

head '/users' do
  send_data
end

post '/users' do
  halt 415 unless request.env['CONTENT_TYPE'] == 'application/json'

  begin
    user = JSON.parse(request.body.read)
  rescue JSON::ParserError => e
    halt 400, send_data(json: -> { { message: e.to_s } },
                        xml: -> { { message: e.to_s } })
  end

  if users[user['first_name'].downcase.to_sym]
    message = { message: "User #{user['first_name']} already in DB." }
    halt 409, send_data(json: -> { message },
                        xml: -> { message })
  end

  users[user['first_name'].downcase.to_sym] = user
  url = "http://localhost:4567/users/#{users['first_name']}"
  response.headers['Location'] = url
  status 201
end

get '/users' do
  send_data(json: -> { users.map { |name, data| data.merge(id: name) } },
            xml: -> { { users: users } })
end

# /users/:first_name
options '/users/:first_name' do
  response.headers['Allow'] = 'GET,PUT,PATCH,DELETE'
  status 200
end

get '/users/:first_name' do |first_name|
  halt 410 if deleted_users[first_name.to_sym]
  halt 404 unless users[first_name.to_sym]

  send_data(json: -> { users[first_name.to_sym].merge(id: first_name) },
            xml: -> { { first_name: users[first_name.to_sym] } })
end

put '/users/:first_name' do |first_name|
  review_media_types(request.content_type)
  find_user(request.body.read)
end

patch '/users/:first_name' do |first_name|
  review_media_types(request.content_type)
  halt 410 if deleted_users[first_name.to_sym]
  halt 404 unless users[first_name.to_sym]

  user_client = JSON.parse(request.body.read)
  user_server = users[first_name.to_sym]

  user_client.each do |key, value|
    user_server[key.to_sym] = value
  end

  send_data(json: -> { user_server.merge(id: first_name) },
            xml: -> { { first_name: user_server } })
end

delete '/users/:first_name' do |first_name|
  first_name = first_name.to_sym
  deleted_users[first_name] = users[first_name] if users[first_name]
  users.delete(first_name)
  status 204
end

%i[put patch delete].each do |method|
  send(method, '/users') do
    halt 405
  end
end

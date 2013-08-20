require 'rubygems'
require 'sinatra'
require 'conjur/api'
require 'conjur-asset-environment'
require 'base64'
require 'json'

$config = {}

ENV['CONJUR_ENV']     = 'production'
ENV['CONJUR_ACCOUNT'] = 'sandbox'
ENV['CONJUR_STACK']   = 'v3'
raise "No NS provided" unless ns = $config[:ns] = ENV['NS']

raise "No SERVICE_API_KEY provided" unless service_api_key = ENV['SERVICE_API_KEY']

$conjur = Conjur::API::new_from_key("host/#{ns}/services/patient-identity", service_api_key)

helpers do
  def ns;  $config[:ns];  end

  def request_headers
    env.inject({}){|acc, (k,v)| acc[$1.downcase] = v if k =~ /^http_(.*)/i; acc}
  end

  def do_login
    token = request_headers['authorization']
    halt(401) unless token
    halt(403) unless token.to_s[/^Token token="(.*)"/]
    @conjur = Conjur::API::new_from_token JSON.parse(Base64.decode64($1))
  end

  def environment_role(environment, role)
    [ 'sandbox', '@', [ environment.attributes['resource_identifier'], role ].join('/') ].join(':')
  end
end

# Create a user
post '/users/' do
  login = params[:login] or halt(400)
  emrid = params[:emrid] or halt(400)
  security_question = params[:question] or halt(400)
  security_answer   = params[:answer]   or halt(400)

  user = $api.create_user(login)

  environment = $api.create_environment("#{ns}/patient-attributes/#{login}").tap do |environment|
    $api.create_variable('text/plain', 'identifier').tap do |variable|
      variable.add_value emrid
      environment.add_variable 'emrid', variable.id
    end
    $api.create_variable('application/json', 'security-question').tap do |variable|
      variable.add_value({ question: security_question, answer: security_answer }.to_json)
      environment.add_variable 'security-question', variable.id
    end
  end

  $api.role(environment_role(environment, 'use_variable')).grant_to "user:$ns-alice"
  $api.role(environment_role(environment, 'use_variable')).grant_to "group:$ns/teams/support"
  
  JSON.pretty_generate user.attributes
end

get '/current-user' do
  do_login

  JSON.pretty_generate @conjur.user(@conjur.username).attributes
end

get '/user/:login/attributes' do
  do_login

  login = params[:login]
  result = @conjur.environment("#{ns}/patient-attributes/#{login}").variables.tap do |result|
    result.each_key do |k|
      result[k] = result[k].value
    end
  end
  JSON.pretty_generate result
end

put '/user/:login/attributes/:key' do
  do_login

  login = params[:login]
  key   = params[:key]
  value = request.body.read

  begin
    @conjur.environment("#{ns}/patient-attributes/#{login}").variable(key).add_value value
    status 204
  rescue RestClient::Forbidden
    halt 403
  end
end


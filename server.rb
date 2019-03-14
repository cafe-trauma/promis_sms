#!/usr/bin/env ruby
require 'twilio-ruby'
require 'sinatra'
require_relative 'ac_api'

USERNAME = ENV['AC_API_USERNAME']
PASSWORD = ENV['AC_API_PASSWORD']
abort("Missing username/password") if USERNAME.nil? || PASSWORD.nil?
$assessment = Assessment.new(USERNAME, PASSWORD)

TSID = ENV['TWILIO_SID']
TTOKEN = ENV['TWILIO_TOKEN']
raise("Missing Auth/Account") if TSID.nil? || TTOKEN.nil?
$t_client = Twilio::REST::Client.new(TSID, TTOKEN)

FROM = '+15014244825' # Your Twilio number
TO = '+15015488376' # Your mobile phone number

def send_message(message)
  $t_client.messages.create(
    from: FROM,
    to: TO,
    body: message
  )
end

post '/sms-quickstart' do
  value = params['Body'].downcase.strip
  puts "RESPONSE - #{value}"
  $assessment.next_question(value)
  twiml = Twilio::TwiML::MessagingResponse.new do |r|
    r.message(body: $assessment.question_string)
  end

  twiml.to_s
end

get '/' do
  @forms = $assessment.get_forms
  erb :index
end

get '/start/:assess_oid' do
  $assessment.start_assessment(params[:assess_oid])
  send_message($assessment.question_string)
  "text sent"
end

#!/usr/bin/env ruby

require 'faraday'
require 'faraday_middleware'
require 'json'
require 'pp'

DEBUG = false

class Assessment
  attr_reader :finished

  def initialize(username, password)
    @conn = Faraday.new(:url => 'https://www.assessmentcenter.net/ac_api/2014-01/') do |faraday|
      faraday.basic_auth(username, password)
      faraday.use FaradayMiddleware::FollowRedirects
      faraday.adapter :net_http
    end
  end

  def get_forms()
    JSON.parse(@conn.get("Forms/.json").body)
  end

  def start_assessment(form_oid)
    @finished = false
    res = @conn.post "Assessments/#{form_oid}.json"
    oid = JSON.parse(res.body)["OID"]
    res = @conn.get "Participants/#{oid}.json"
    @assessment_oid = oid
    @cur_question = JSON.parse(res.body)
    if DEBUG
      puts @assessment_oid
      puts @cur_question
    end
  end

  def next_question(value)
    element_oid = @options[value]
    puts "#{element_oid} - #{value}" if DEBUG
    res = @conn.post do |r|
      r.url "Participants/#{@assessment_oid}.json"
      r.params['ItemResponseOID'] = element_oid
      r.params['Response'] = value
    end
    unless res.success?
      puts res.status
      puts res.body
      @finished = true
    else
      @cur_question = JSON.parse(res.body)
      if @cur_question['DateFinished'] != ""
        @finished = true
      end
    end
  end

  def question_string()
    return score_assessment if @finished
    @options = {}
    q_string = ""
    @cur_question["Items"].first["Elements"].each do |element|
      if element.key? "Map"
        element["Map"].each do |map|
          @options[map['Value']] = map['ItemResponseOID']
          q_string << "#{map['Value']} - #{map['Description']}\n"
        end
      else
        q_string << "#{element["Description"]}\n"
      end
    end
    q_string
  end

  def score_assessment()
    res = @conn.get "Results/#{@assessment_oid}.json"
    results = JSON.parse(res.body)
    "#{results['Name']} - #{results['StdError']} - #{results['Theta']}"
  end
end


if __FILE__ == $0
  USERNAME = ENV['AC_API_USERNAME']
  PASSWORD = ENV['AC_API_PASSWORD']

  abort("Missing username/password") if USERNAME.nil? || PASSWORD.nil?
  form_oid = ARGV.first
  form_oid ||= 'C5D120A9-D2CD-4A2A-9CFA-8D57877BE9C1'
  a = Assessment.new(USERNAME, PASSWORD)
  a.start_assessment(form_oid)
  until a.finished do
    puts a.question_string
    v = STDIN.gets.chomp
    a.next_question(v)
  end
  puts a.question_string
end

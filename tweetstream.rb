require 'rubygems'
require 'tweetstream'
require 'oj'
require 'colored'
require 'redis'
require 'uri'
require './lib/terms'

# configure tweetstream instance
TweetStream.configure do |config|
  config.consumer_key       = ENV['CONSUMER_KEY']
  config.consumer_secret    = ENV['CONSUMER_SECRET']
  config.oauth_token        = ENV['OAUTH_TOKEN']
  config.oauth_token_secret = ENV['OAUTH_TOKEN_SECRET']
  config.auth_method = :oauth
end

# db setup
uri = URI.parse(ENV["REDISTOGO_URL"])
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

# my options
VERBOSE = ENV["VERBOSE"] || false

#setup
$stdout.sync = true
log = Logger.new(STDOUT)
log.level = Logger::DEBUG if VERBOSE

#DONE: load terms from json
#DONE: create name->twitter hash map
TERMS=Terms.new(Oj.load_file('config/cfda.twitter.json'))

puts "Setting up a stream to track terms '#{TERMS.list}'..."
@client = TweetStream::Client.new
@client.on_error do |message|
  # Log your error message somewhere
  puts "ERROR: #{message}"
end
@client.on_limit do |skip_count|
  # do something
  puts "RATE LIMITED LOL"
end
@client.track(TERMS.list) do |status|
  puts " ** @#{status.user.screen_name}: ".green + status.text.white if VERBOSE
  status_small = {
    'id' => status.id.to_s,
    'text' => status.text,
    'username' => status.user.screen_name
  }
  status_json = Oj.dump(status_small)

  #bail out if a retweet
  if status.text.start_with? "RT "
    log.debug " -> Ignored tweet since it's a stupid RT!"
    next
  end

  #try to detect images
  detected_images = []
  status.urls.each do |url|
    url = url.expanded_url
    url_is_image = true ? url.start_with?('http://instagr.am/p/') : false
    log.debug "   -> detected url: #{url}"
    log.debug "   -> OMG ITS AN IMAGE!" if url_is_image
    detected_images << url if url_is_image
  end

  #figure out which term we matched
  #and normalize terms to twitter
  matched_terms = []
  TERMS.list.each do |term|
    if status.text.include? term
      matched_terms.push(TERMS.normalize(term))
    end
  end

  #for each matched term, push to the results
  matched_terms.each do |term|
    REDIS.pipelined do
      REDIS.ZINCRBY "scores",1,term
      REDIS.PUBLISH "#{term}_stream", status_json
      REDIS.LPUSH "#{term}_tweets", status_json
      REDIS.LTRIM "#{term}_tweets",0,9
    end

    detected_images.each do |img|
      REDIS.INCR "#{term}_image_count"
      REDIS.LPUSH "#{term}_images", img
      REDIS.LTRIM "#{term}_images",0,9
    end
  end

end

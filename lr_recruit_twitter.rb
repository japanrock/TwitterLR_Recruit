#!/usr/bin/env ruby
# coding: utf-8

require 'rubygems'
require 'oauth'
require 'json'
require 'hpricot'
require 'open-uri'
require 'yaml'
require 'parsedate'
require "kconv"

### TODO:
### ・TwitterBaseクラスを外に出す

# Usage:
# ruby lr_recruit_twitter.rb /path/to/sercret_keys.yml

# TwitterのAPIとのやりとりを行うクラス
class TwitterBase
  def initialize
    # config.yml内のsercret_keys.ymlをloadします。
    @secret_keys = YAML.load_file(ARGV[0] || 'sercret_keys.yml')
  end
  
  def consumer_key
    @secret_keys["ConsumerKey"]
  end

  def consumer_secret
    @secret_keys["ConsumerSecret"]
  end

  def access_token_key
    @secret_keys["AccessToken"]
  end

  def access_token_secret
    @secret_keys["AccessTokenSecret"]
  end

  def consumer
    @consumer = OAuth::Consumer.new(
      consumer_key,
      consumer_secret,
      :site => 'http://twitter.com'
    )
  end

  def access_token
    consumer
    access_token = OAuth::AccessToken.new(
      @consumer,
      access_token_key,
      access_token_secret
    )
  end

  def post(tweet=nil)
    response = access_token.post(
      'http://twitter.com/statuses/update.json',
      'status'=> tweet
    )
  end
end

# MyNaviのテキストを扱うクラス
# TODO:
# 「会社説明会」「セミナー（２つ）」を別々のクラスで作る
class MyNavi
  attr_reader :dates
  attr_reader :times
  attr_reader :prices
  attr_reader :title
  
  def initialize
    @all_dates  = []
    @all_times = []
    @all_prices = []
    @dates  = []
    @times  = []
    @prices = []
    @title  = []
  end

  def base_url
    "http://job.mynavi.jp/"
  end

  def feed
    (open_feed.search("h2")).each do |elems|
      @title << elems.inner_html.toutf8
    end

    (open_feed.search("td.date")).each do |elems|
      @all_dates << elems.inner_html.toutf8
    end

    (open_feed.search("td.time")).each do |elems|
      @all_times << elems.inner_html.toutf8
    end

    (open_feed.search("td.place")).each do |elems|
      @all_prices << elems.inner_html.toutf8
    end
  end

  def filter
    return self if @all_dates.empty?

    @all_dates.each_with_index do |date, index|
      date = ParseDate::parsedate(date)

      if date[0]
        time = Time.now
        # 10日先ジャストの告知取得
        if interval == (Time.local(date[0].to_i, date[1].to_i, date[2].to_i) - Time.local(time.year, time.month, time.day)).divmod(24*60*60)[0]
          @dates  << @all_dates[index] 
          @times  << @all_times[index]
        end
      end
    end
  end

  private
  # フィードをHpricotのオブジェクトにします。
  def open_feed
    Hpricot(open(base_url))
  end

  # days
  def interval
    10
  end
end

# 会社説明会
class BriefingSession < MyNavi
  def base_url
    "http://job.mynavi.jp/11/pc/NSSearchSeminarInfo.do?optNum=4pgO7C&corpId=75729"
  end

  def link
    base_url
  end
end

twitter_base     = TwitterBase.new
briefing_session = BriefingSession.new
briefing_session.feed
briefing_session.filter

briefing_session.dates.each_with_index do |date, index|
  twitter_base.post("#{briefing_session.title}" + " " + "#{briefing_session.dates[index]}" + " " + "#{briefing_session.times[index]}" + " " + "#{briefing_session.link}")
end

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
require File.dirname(__FILE__) + '/twitter_oauth'

# Usage:
#  1. このファイルと同じディレクトリに以下2つのファイルを設置します。
#   * twitter_oauth.rb
#   * http://github.com/japanrock/TwitterTools/blob/master/twitter_oauth.rb
#   * sercret_key.yml
#   * http://github.com/japanrock/TwitterTools/blob/master/secret_keys.yml.example
#  2. このファイルを実行します。
#   ruby lr_recruit_twitter.rb

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

twitter_oauth    = TwitterOauth.new
briefing_session = BriefingSession.new
briefing_session.feed
briefing_session.filter

briefing_session.dates.each_with_index do |date, index|
  twitter_oauth.post("#{briefing_session.title}" + " " + "#{briefing_session.dates[index]}" + " " + "#{briefing_session.times[index]}" + " " + "#{briefing_session.link}")
end

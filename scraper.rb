#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('td.leg03_news_search_03 a[href*="legIntro.action"]/@href').each do |href|
    link = URI.join url, href
    scrape_person(link)
  end
end

def scrape_person(url)
  noko = noko_for(url)

  box = noko.css('.container')
  find_li = ->(str) { 
    found = box.css('.c01 li').find { |t| t.text.downcase.include?(str + ":") }
    binding.pry unless found
    found.text.split(/\s*:\s*/,2).last
  }

  data = { 
    id: url.to_s[/lgno=(\d+)/, 1],
    name: box.css('div.name').text.tidy.split(/\s*,\s*/, 2).reverse.join(' '),
    sort_name: box.css('div.name').text.tidy,
    image: box.css('img.leg03_pic/@src').text,
    gender: find_li.('gender').downcase,
    party: find_li.('party'),
    faction: find_li.('party organization'),
    area: find_li.('electoral district'),
    start_date: find_li.('date of commencement').to_s.gsub('/','-'),
    term: 8,
    source: url.to_s,
  }
  data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?

  zh_url = url.to_s.sub('en/03_leg','03_leg/0301_main')
  noko_zh = noko_for(zh_url)
  data[:name__zh] = noko_zh.css('td.leg03_titbg07').text.sub('委員','')

  ScraperWiki.save_sqlite([:id, :term], data)
end

scrape_list('http://www.ly.gov.tw/en/03_leg/legList.action')

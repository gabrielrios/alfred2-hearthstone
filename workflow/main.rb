#!/usr/bin/env ruby
# encoding: utf-8

($LOAD_PATH << File.expand_path("..", __FILE__)).uniq!

require 'rubygems' unless defined? Gem # rubygems is only needed in 1.8
require "bundle/bundler/setup"
require "alfred"
require 'json'

class Card
  attr_reader :fb, :card, :type
  def initialize(fb, card)
    @fb = fb
    @id = card["id"]
    @type       = card["type"]
    @name       = card["name"]
    @cost       = card["cost"]
    @attack     = card["attack"]
    @durability = card["durability"]
    @health     = card["health"]
    @quality    = card["rarity"]
    @class      = card["playerClass"] unless card["playerClass"].nil?
    @durability       = card["durability"] unless card["durability"].nil?
    @race       = card["race"] unless card["race"].nil?
    @set       = card["set"] unless card["set"].nil?
    @text       = card["text"] unless card["text"].nil?
    @flavor     = card["flavor"] unless card["flavor"].nil?
  end

  def format
    fb.add_item({
      uid: "#{@id}_name",
      icon: { :type => "default", :name => rarity_icon },
      title: @name,
      subtitle: @flavor,
      arg: url
    })
    fb.add_item({
      uid: "#{@id}_text",
      icon: { :type => "default", :name => "icon.png" },
      title: @text.to_s,
    })
    fb.add_item({
      uid: "#{@id}_cost",
      icon: { :type => "default", :name => "icons/mana.png" },
      title: @cost.to_s
    })
    if minion? || weapon?
      fb.add_item({
        uid: "#{@id}_attack",
        icon: { :type => "default", :name => "icons/#{'weapon_' if weapon?}attack.png" },
        title: @attack
      })
    end
    if weapon?
      fb.add_item({
        uid: "#{@id}_durability",
        icon: { :type => "default", :name => "icons/durability.png" },
        title: @durability
      })
    end
    if minion?
      fb.add_item({
        uid: "#{@id}_health",
        icon: { :type => "default", :name => "icons/health.png" },
        title: @health
      })
    end
    if @class
      fb.add_item({
        uid: "#{@id}_class",
        icon: { :type => "default", :name => "icons/#{@class.downcase}.png" },
        title: "#{@class} Card"
      })
    end
    if @type || @race
      t = "Type: #{@type}" if @type
      r = "Race: #{@race}" if @race
      s = "Set: #{@set}" if @set
      fb.add_item({
        uid: "#{@id}_type",
        icon: { :type => "default", :name => "icon.png" },
        title: [t,r, s].compact.join(" | "),
      })
    end

  end

  def url
    "http://hearthhead.com/card=#{@id}"
  end

  def minion?
    @type.downcase == "minion"
  end

  def weapon?
    @type.downcase == "weapon"
  end

  def rarity_icon
    @quality.nil? || @quality.downcase == "free" ? "icon.png" : "icons/#{@quality.downcase}.png"
  end
end

class HearthStoneSearcher
  attr_reader :fb
  def initialize(fb)
    @fb = fb
    @sets = JSON.parse(File.read("./sets8.json"))
    @cards = JSON.parse(File.read("./cards.json"))
    @sets.reject! { |set| ["Credits", "Debug", "Missions", "System"].include?(set)  }
  end

  def search(arg, field = "name")
    if arg =~ /\w{3}_\d{3}\S*/
      arg = arg.scan(/\w{3}_\d{3}\S*/).first
      field = "id"
    end

    cards = @sets.flat_map do |set|
      cards = @cards[set].select {|card| card[field].downcase.include?(arg.downcase) && card["type"].downcase != "hero" }
      cards.each {|c| c['set'] = set }
      cards
    end

    if cards.size == 1
      Card.new(fb, cards.first).format
    else
      cards.map do |card|
        fb.add_item({
          uid: card["id"],
          title: format_title(card),
          subtitle: card["text"],
          valid: 'no',
          autocomplete: "#{card["name"]} #{card["id"]}"
        })
      end
    end
  end

  def format_title(card)
    "#{card["name"]} (#{card["cost"]})  #{card['attack']}/#{card['health'] || card['durability']}"
  end

  def to_xml
    fb.to_xml
  end
end


Alfred.with_friendly_error do |alfred|
  fb = alfred.feedback

  searcher = HearthStoneSearcher.new(fb)
  searcher.search(ARGV.join(" "))

  puts searcher.to_xml
end




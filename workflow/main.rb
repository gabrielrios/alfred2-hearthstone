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
    @fb             = fb
    @id             = card["id"]
    @type           = card["type"]
    @name           = card["name"]
    @cost           = card["cost"]
    @attack         = card["attack"]
    @health         = card["health"]
    @quality        = card["rarity"]
    @collectible    = card["collectible"]
    @url            = card["name"].downcase.gsub(/\s+/, '-').gsub(/\'+/,'').gsub(/\,/,'')
    @class          = card["playerClass"] unless card["playerClass"].nil?
    @durability     = card["durability"] unless card["durability"].nil?
    @race           = card["race"] unless card["race"].nil?
    @set            = card["set"] unless card["set"].nil?
    @text           = card["text"] unless card["text"].nil?
    @flavor         = card["flavor"] unless card["flavor"].nil?
    @dust           = card["dust"] unless card["dust"].nil?
    @mechanics      = card["mechanics"] unless card["mechanics"].nil?
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
      title: @text.to_s.gsub(/\n/, ' ').gsub(%r{</?[^>]+?>}, ''),
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
        title: "#{@class.split.map(&:capitalize).join(' ')} Card"
      })
    end
    if @type || @race

      fullSets = {
        "EXPERT1"      => 'Default',
        "CORE"         => 'Core',
        "NAXX"         => 'Naxaramus',
        "GVG"          => 'Goblins vs Gnomes',
        "BRM"          => 'Blackrock Mountain',
        "TGT"          => 'The Grand Tournamanet',
        "LOE"          => 'The League of Explorers',
        "OG"           => 'Whispers of the Old Gods ',
        "KARA"         => 'One Night in Karazan',
        "GANGS"        => 'Mean Streets of Gadgetzan',
      }

      t = "Type: #{@type}".split.map(&:capitalize).join(' ') if @type
      r = "Race: #{@race}".split.map(&:capitalize).join(' ') if @race
      @ss = fullSets[@set]
      s = "Set: #{@ss}" if @set
      # s = "Set: #{@set}" if @set
      fb.add_item({
        uid: "#{@id}_type",
        icon: { :type => "default", :name => "icon.png" },
        title: [t, r, s].compact.join(" | "),
      })
    end

  end

  def url
    # "http://hearthhead.com/card=#{@id}"
    #@url
    @name
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
    # @sets = JSON.parse(File.read("./sets8.json"))
    @cards = JSON.parse(File.read("./cards.collectible.json"))
    # @sets.reject! { |set| ["Credits", "Debug", "Missions", "System"].include?(set)  }
  end

  def search(arg, field = "name")
    if arg =~ /\w{3}_\d{3}\S*/
      arg = arg.scan(/\w{3}_\d{3}\S*/).first
      field = "id"
    end

    # cards = @sets.flat_map do |set|
    cards = @cards.select {|card| card[field].downcase.include?(arg.downcase) && card["type"].downcase != "hero" }
      # cards.each {|c| c['set'] = set }
    cards
    # end

    if cards.size == 2
      # print 'someshit'
      Card.new(fb, cards.first).format
      second = cards[1]
      fb.add_item({
          title: '-------------- MORE CARDS --------------',
          icon: { :type => "default", :name => "icons/blank.png" },
        })
      fb.add_item({
          second: second["id"],
          title: format_title(second),
          subtitle: second["text"],
          valid: 'no',
          autocomplete: "#{second["name"]}"
        })

    elsif cards.size == 1
      Card.new(fb, cards.first).format
    else
      cards.map do |card|
        fb.add_item({
          uid: card["id"],
          title: format_title(card),
          subtitle: card["text"],
          valid: 'no',
          autocomplete: "#{card["name"]}"
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




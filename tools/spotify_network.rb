#!/usr/bin/env ruby

# https://github.com/obrie/spotify_web/
require 'spotify_web'
require 'json'
require 'dotenv'

Dotenv.load
username = ENV['spotify_username']
password = ENV['spotify_password']

@spotify = SpotifyWeb::Client.new(username, password)

MAX_CUTTOFF = 12
MATCH_CUTTOFF = 0.07

@ids = []
@current_songs = []

def id_for(song)
  id = [song["name"], song["artist"]].join("_")
  id = id.downcase().gsub(/\s+/,"_").gsub(/\W+/,"")

  # if @ids.include? id
  #   puts "WARNING: already have id for:#{song["name"]}"
  # end
  @ids << id
  id
end


# Get similar songs
def get_similar(old_song)
  puts old_song
  begin
  results = @spotify.song.similar(old_song["artist"], old_song["name"])
  rescue Exception => msg
    puts "ERROR: #{msg}"
    results = []
  end
  songs = []
  # puts results.inspect
  results.each do |r|
    match = r["match"].to_f
    if match > MATCH_CUTTOFF
      song = {}
      song["match"] = match
      song["name"] = r["name"]
      song["artist"] = r["artist"]["name"]
      song["id"] = id_for(song)
      song["playcount"] = r["playcount"].to_i
      songs << song
    end
  end
  songs
end

def links_for(origin, songs)
  links = []
  songs.each do |song|
    link = {"source" => origin["id"], "target" => song["id"]}
    reverse_link = {"target" => origin["id"], "source" => song["id"]}
    if !links.include?(link) and !links.include?(reverse_link)
      links << link
    end
  end
  links
end

def unseen_songs(current_songs, new_songs)
  unseen = []
  current_song_ids = current_songs.collect {|cs| cs["id"]}
  new_songs.each do |song|
    if !current_song_ids.include? song["id"]
      unseen << song
    end
  end
  unseen
end

def expand(songs, links, root)
  new_songs = get_similar(root)
  unseen = unseen_songs(songs, new_songs)[0..MAX_CUTTOFF]
  new_links = links_for(root, unseen)
  [unseen, new_links]
end


def grab(root, output_filename)
  links = []
  all_songs = []

  first_iteration, new_links = expand(all_songs, links, root)

  all_songs.concat first_iteration
  links.concat(new_links)

  unlinked_songs = []

  puts all_songs.length
  first_iteration.clone()[1..-1].each do |song|
    puts song["name"]
    new_songs, new_links = expand(all_songs, links, song)
    all_songs.concat(new_songs)
    unlinked_songs.concat(new_songs)
    links.concat(new_links)
    puts all_songs.length
  end

  # second_iteration = all_songs.sample(10)
  # second_iteration.each do |song|
  #   puts song["name"]
  #   new_songs, new_links = expand(all_songs, links, song)
  #   all_songs.concat(new_songs)
  #   unlinked_songs.concat(new_songs)
  #   links.concat(new_links)
  #   puts all_songs.length
  # end

  # song_ids = all_songs.collect {|s| s["id"]}
  # second_iteration = all_songs.sample(20)
  # second_iteration.each do |song|
  #   new_songs = get_similar(song)
  #   new_links = []
  #   new_songs.each do |sim_song|
  #     if song_ids.include?(sim_song["id"]) and sim_song["match"] > MATCH_CUTTOFF
  #       new_links << sim_song
  #     end
  #   end
  #   links.concat(links_for(song, new_links))
  # end


  data = {}
  data["nodes"] = all_songs
  data["links"] = links
  File.open(output_filename, 'w') do |file|
    file.puts JSON.pretty_generate(JSON.parse(data.to_json))
  end
end

roots = [
  # {"name" => "Halo", "artist" => "Beyoncé", "filename" => "halo.json"},
  # {"name" => "Thriller", "artist"  => "Michael Jackson", "filename" => "thriller.json"},
  # {"name" => "Hotline Bling", "artist"  => "Drake", "filename" => "hotline_bling.json"},
  # {"name" => "I Will Always Love You", "artist"  => "Whitney Houston", "filename" => "i_will_always_love_you.json"},
  # {"name" => "Despacito", "artist" => "Luis Fonsi", "filename" => "despacito.json"},
  # {"name" => "Apologize", "artist" => "Timbaland", "filename" => "apologize.json"},
  # {"name" => "Respect", "artist" => "Aretha Franklin", "filename" => "respect.json"},
  # {"name" => "Billie Jean", "artist" => "Michael Jackson", "filename" => "billie_jean.json"},
  # {"name" => "Pray For Me", "artist" => "The Weeknd", "filename" => "pray_for_me.json"},
  # {"name" => "Run the World (Girls)", "artist" => "Beyoncé", "filename" => "run_the_world.json"}
  {"name" => "Alright", "artist" => "Kendrick Lamar", "filename" => "alright.json"}
]

roots.each do |root|
  root["id"]  = id_for(root)

  grab(root, root["filename"])
end

#!/usr/bin/env ruby

# Regular Expression patterns:
#
# Capture s01e01 style (US Style):
# [s|S](\d+)[e|E](\d+)
#
# Capture 1x01 style (EU Style):
# (\d+)[x|X](\d+)
#
# Babylon 5:
# 5.(\d)(\d+)
#
# Stein's Gate EP01:
# [e|E][p|P](\d+)
#
# UPDATE Jan 8 2015:
# Just noticed that they changed the way to obtain the XML file (@series_xml = ...)
# Add a new update if they do it again.
#

require 'optparse'
require 'open-uri'
require 'nokogiri'

$TVDB_API_KEY = '7FEBFD17ED32D7B2'
$VERBOSE = false


def search_directory(folder='.', search_for='*')
  result = []
  if search_for != nil then
    search_for = File.join(folder, search_for)
  else
    search_for = folder
  end
  Dir.glob(search_for).each do |file|
    result << file
  end
  return result
end


def vputs(x)
  puts x if $VERBOSE
end


class FormatSeriesOptions
  def initialize()
    @params = Hash.new(nil)
    @option_parser = OptionParser.new()
    @option_parser.banner = "Usage: formatseries.rb {options} SeriesName path/to/series/directory"
    @option_parser.on('-h', '--help', 'Displays this information') do
      display_usage()
    end
    @option_parser.on('-v', '--verbose', 'Displays debug information') do
      $VERBOSE = true
    end
    @option_parser.on('-d', '--dry', "Does a 'dry run'") do
      @params[:dry] = true
    end
    @option_parser.on('-sLANG', '--sub=LANG', 'Makes the subtitles have .[LANG].[ext] for plex') do |lang|
      @params[:subs] = lang
    end
  end
  
  def display_usage()
    puts(@option_parser)
    exit()
  end
  
  def [](x)
    return @params[x]
  end
  
  def []=(x, y)
    @params[x] = y
  end
  
  def parse_args(*args)
    unparsed = @option_parser.parse(*args)
    if unparsed.count() == 2 then
      self[:unparsed] = unparsed.collect {|x| x.gsub('\\', '/')}
    else
      puts("Need to specify a series name and series directory!\n\n")
      display_usage()
    end
    self
  end
end


class FormatSeries
  def initialize(series_name)
    @series_name = series_name
    @series_id = Nokogiri::XML(open("http://thetvdb.com/api/GetSeries.php?seriesname=#{@series_name.gsub(' ', '%20')}")).at_xpath("//seriesid").child().content()
    @series_xml = Nokogiri::XML(open("http://thetvdb.com/api/#{$TVDB_API_KEY}/series/#{@series_id}/all/"))
    
    @pattern_array = [/[e|E][p|P](\d+)/, /[s|S](\d+)[e|E](\d+)/, /(\d+)[x|X](\d+)/, /(\d+)[.](\d+)/, /[S|s]eason\D?(\d+).?[E|e]pisode\D?(\d+)/]
  end
  
  def add_pattern(pattern)
    @pattern_array.unshift(pattern) if pattern.class == Regexp
  end
  
  def episode_exists?(season_number, episode_number)
    return get_episode_name(season_number, episode_number) != nil
  end
  
  def extension_is_subtitle?(extension)
    if ['sub', 'idx', 'srt'].include?(extension) then
      return true
    else
      return false
    end
  end
  
  def get_episode_name(season_number, episode_number)
    episode_name_xml = @series_xml.at_xpath("//Episode[SeasonNumber=\"#{season_number}\" and EpisodeNumber=\"#{episode_number}\"]/EpisodeName")
    if episode_name_xml then
      return episode_name_xml.child().content().gsub(/[?"]/, '').gsub(/[*:<>\/]/, ' ')
    else
      return nil
    end
  end
  
  def format_filename(season_number, episode_number, extension, subs_lang=nil)
    episode_name = get_episode_name(season_number, episode_number)
    if episode_name then
      if subs_lang and extension_is_subtitle?(extension) then
        return "#{@series_name} - s#{season_number.to_s().rjust(2, "0")}e#{episode_number.to_s().rjust(2, "0")} - #{episode_name}.#{subs_lang}.#{extension}"
      else
        return "#{@series_name} - s#{season_number.to_s().rjust(2, "0")}e#{episode_number.to_s().rjust(2, "0")} - #{episode_name}.#{extension}"
      end
    else
      return nil
    end
  end
  
  def rename_file(filepath, new_filename)
    File.rename(filepath, filepath.gsub(filepath.split('/').last(), new_filename))
  end
  
  def format_series(series_dir, rename_files=true, subs_lang=nil)
    filepath_array = search_directory(series_dir, '*.*')
    
    filepath_array.each() do |filepath|
      filename = filepath.split('/').last()
      extension = filename.split('.').last()
      
      match_pattern = @pattern_array.select(){|pattern| pattern.match(filename)}[0] # try to select a pattern from the pattern array
      
      match_data = nil
      if match_pattern then # if a pattern was found
        match_data = match_pattern.match(filename)
      end
      
      if match_data then
        if match_data.length() == 2 then
          # Only got an episode number, assume there is only one season
          episode_number = match_data[1].to_i()
          if episode_exists?(1, episode_number) then
            new_filename = format_filename(1, episode_number, extension, subs_lang)
          else
            vputs("No episode information found for S01 E#{episode_number}!")
            new_filename = filename
          end
        else
          # Got a season and episode number, procede normally
          season_number = match_data[1].to_i()
          episode_number = match_data[2].to_i()
          if episode_exists?(season_number, episode_number) then
            new_filename = format_filename(season_number, episode_number, extension, subs_lang)
          else
            vputs("No episode information found for S#{season_number} E#{episode_number}!")
            new_filename = filename
          end
        end
        # Now we have all the information, let's rename those files!
        if filename == new_filename then
          vputs("Skipped -- #{filename}")
        else
          vputs("#{filename} >> #{new_filename}")
          rename_file(filepath, new_filename) if rename_files
        end
      end
    end
  end
end


options = FormatSeriesOptions.new().parse_args(*ARGV)
fs = FormatSeries.new(options[:unparsed][0])
#fs.add_pattern(/5.(\d)(\d+)/)

fs.format_series(options[:unparsed][1], !options[:dry], options[:subs])



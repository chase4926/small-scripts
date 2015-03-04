
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
#
# UPDATE Jan 8 2015:
# Just noticed that they changed the way to obtain the XML file (@series_xml = ...)
# Add a new update if they do it again.
#

require 'open-uri'
require 'nokogiri'

$TVDB_API_KEY = '7FEBFD17ED32D7B2'


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


class FormatSeries
  def initialize(series_name)
    @series_name = series_name
    @series_id = Nokogiri::XML(open("http://thetvdb.com/api/GetSeries.php?seriesname=#{@series_name.gsub(' ', '%20')}")).at_xpath("//seriesid").child().content()
    @series_xml = Nokogiri::XML(open("http://thetvdb.com/api/#{$TVDB_API_KEY}/series/#{@series_id}/all/"))
    
    @pattern_array = [/[s|S](\d+)[e|E](\d+)/, /(\d+)[x|X](\d+)/, /(\d+)[.](\d+)/, /[S|s]eason\D?(\d+).?[E|e]pisode\D?(\d+)/]
  end
  
  def add_pattern(pattern)
    @pattern_array << pattern if pattern.class == Regexp
  end
  
  def get_episode_name(season_number, episode_number)
    #puts "S[#{season_number}] E[#{episode_number}]"
    return @series_xml.at_xpath("//Episode[SeasonNumber=\"#{season_number}\" and EpisodeNumber=\"#{episode_number}\"]/EpisodeName").child().content().gsub(/[?"]/, '').gsub(/[*:<>]/, ' ')
  end
  
  def format_filename(season_number, episode_number, extension)
    return "#{@series_name} - s#{season_number.to_s().rjust(2, "0")}e#{episode_number.to_s().rjust(2, "0")} - #{get_episode_name(season_number, episode_number)}.#{extension}"
  end
  
  def rename_file(filepath, new_filename)
    File.rename(filepath, filepath.gsub(filepath.split('/').last(), new_filename))
  end
  
  def format_series(series_dir, rename_files=true)
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
        puts "#{filename} >> #{format_filename(match_data[1].to_i(), match_data[2].to_i(), extension)}"
        rename_file(filepath, format_filename(match_data[1].to_i(), match_data[2].to_i(), extension)) if rename_files
      end
    end
  end
end



a = FormatSeries.new('Boardwalk Empire')
#a.add_pattern(/5.(\d)(\d+)/)
a.format_series("C:/Users/Chase/Downloads/Boardwalk Empire/Season 05", true)


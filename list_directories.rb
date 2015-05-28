


dirs = Array.new() # dirs = directories
list = Array.new() # result list
dirs << 'K:/Movies'
dirs << 'L:/Movies'


dirs.each() do |dir|
  Dir.glob("#{dir}/*").each() do |filename|
    list << filename.split('/').last()
  end
end

list.sort!()
File.open('list.txt', 'w+') do |file|
  file.print(Time.now().to_s())
  file.print("\n\n")
  
  file.print(list.join("\n"))
end


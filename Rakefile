require 'yui/compressor'

task default: %w[css_minify js_minify]

CSS_FILES = [
  ['static/style.css', 'static/style.min.css'],
  ['static/style.board.css', 'static/style.board.min.css']
]
CSS_BANNER = "/* Copyright 2018, Daniel Oltmanns (https://github.com/oltdaniel) */\n"
JS_FILES = [
  ['static/script.js', 'static/script.min.js']
]
JS_BANNER = "/* Copyright 2018, Daniel Oltmanns (https://github.com/oltdaniel) */\n"

task :css_minify do
  puts 'Minifying css...'
  compressor = YUI::CssCompressor.new
  CSS_FILES.each do |v|
    File.write(v[1], CSS_BANNER + compressor.compress(File.read(v[0])))
  end
end

task :js_minify do
  puts 'Minifying js...'
  compressor = YUI::JavaScriptCompressor.new(:munge => true)
  JS_FILES.each do |v|
    File.write(v[1], JS_BANNER + compressor.compress(File.read(v[0])))
  end
end

task :watch_minify do
  require 'listen'
  listener = Listen.to('static', ignore: /\.min\.(css|js)/) do |modified, added, removed|
    if modified || added || removed
      puts 'Compiling...'
      ['css_minify', 'js_minify'].each { |t| Rake::Task[t].execute }
    end
  end
  listener.start
  puts 'Watching for changes...'
  sleep
rescue SystemExit, Interrupt
end

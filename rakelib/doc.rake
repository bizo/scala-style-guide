
task 'doc:setup'

begin
  require 'jekylltask'
  module TocFilter
    def toc(input)
      output = "<ol class=\"toc\">"
      input.scan(/<(h2)(?:>|\s+(.*?)>)([^<]*)<\/\1\s*>/mi).each do |entry|
        id = (entry[1][/^id=(['"])(.*)\1$/, 2] rescue nil)
        title = entry[2].gsub(/<(\w*).*?>(.*?)<\/\1\s*>/m, '\2').strip
        if id
          output << %{<li><a href="##{id}">#{title}</a></li>}
        else
          output << %{<li>#{title}</li>}
        end
      end
      output << "</ol>"
      output
    end
  end
  Liquid::Template.register_filter(TocFilter)

  desc "Generate documentation in _site/"
  JekyllTask.new :jekyll do |task|
    task.source = 'doc'
    task.target = '_site'
  end

rescue LoadError
  puts "jekyll gem required to generate the Web site. You can install it by running rake doc:setup"
  task 'doc:setup' do
    install_gem 'jekyll', :version=>'0.11.0'
    install_gem 'jekylltask', :version=>'1.1.0'
    if `pygmentize -V`.empty?
      args = %w{easy_install Pygments}
      args.unshift 'sudo' unless Config::CONFIG['host_os'] =~ /windows/
      sh *args
    end
  end
end

PDF = 'bizo-scala-style-guide.pdf'

desc "Generate PDF documentation"
file PDF => '_site' do |task|
  pages = File.read('_site/preface.html').scan(/<li><a href=['"]([^'"]+)/).flatten.map { |f| "_site/#{f}" }
  sh 'prince', '--input=html', '--no-network', '--log=prince_errors.log', "--output=#{task.name}", '_site/preface.html', *pages
end

desc "Build a copy of the Web site in the ./_site"
task :site=>[:jekyll, '_site', PDF] do
  cp 'CHANGELOG', '_site'
  cp PDF, '_site'
  fail 'No PDF in site directory' unless File.exist?("_site/#{PDF}")
  puts 'OK'
end

# Publish prerequisites to Web site.
task :publish => :site do
  rm_f PDF
  stashed = `git stash` !~ /No local changes to save/
  sh 'git push origin gh-pages'
  sh 'git co gh-pages'
  sh 'cp -r _site/* .'
  entries = `git status -s`.split("\n")
  entries.each do |e|
    status, file = [e[0..1], e[3..-1]]
    case status
    when ' M'
      `git add #{file}`
    when '??'
      `git add #{file}` if File.exist?(File.join('_site', file))
    else
      puts "Unexpected status '#{status}' for #{file}"
    end
  end
  sh 'git commit -m "Update site" .'
  sh 'git push origin gh-pages'
  sh 'git checkout master'
  sh 'git stash pop' if stashed
  puts "Done"
end

task :clobber do
  rm_rf '_site'
  rm_f PDF
  rm_f 'prince_errors.log'
end

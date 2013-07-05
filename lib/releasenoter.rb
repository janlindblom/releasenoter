require 'releasenoter/version'
require "git"
require 'rake'
require 'rake/tasklib'
require 'yaml'

module Releasenoter
  class Tasks < ::Rake::TaskLib
    def initialize(namespace = :releasenote)
    
      namespace(namespace) do
        desc "Generate Release Notes"
        task :generate, :until, :since do |t, args|
          config = Releasenoter::Config.parse
          
          @jira_inst = config["jira"]
          @github_repo = config["github_repo"] || get_remote
          @github_link_commit = config["link_commit"] || false
          @author_email = config["author_email"]
          @show_author = config["show_author"]
          @long_hash = config["long_hash"]
          @until = args[:until] || nil
          @since = args[:since] || nil
          @format = config["format"]
          
          define_format
          
          get_tags
          get_log
        end
      end
    end
    
    private
    
    def define_format
      if @format == "markdown"
        @h3 = "###"
        @h4 = "####"
        @bull = " *"
        @link = {:text_b => '[', :text_a => ']', :link_b => '(', :link_a => ')'}
      elsif @format == "textile"
        @h3 = "h3."
        @h4 = "h4."
        @bull = " *"
        @link = {:text_b => '"', :text_a => '":', :link_b => '', :link_a => ''}
      end
    end
    
    def get_tags
      @git = Git.open('.')
    end
    
    def get_remote
      @git = Git.open('.')
      gh_repo_pat = /git@github\.com\:(\w.+\w)\.git/
      remote_origin = @git.remote('origin').url
      remote = false
      
      if remote_origin =~ gh_repo_pat
        remote = 'https://github.com/' + remote_origin.sub(gh_repo_pat, '\1')
      end
      return remote
    end
    
    def highlight_commit_message(commit_message)
      
      
      if commit_message =~ @jira_pat
        @issues.push(commit_message.match(@jira_pat)[0])
        
        if @jira_inst
          commit_message = commit_message.sub(@jira_pat, '['+@link[:text_b]+'\1'+@link[:text_a]+@link[:link_b]+@jira_inst+'/browse/\1'+@link[:link_b]+']')
        else
          commit_message = commit_message.sub(@jira_pat, '[\1]')
        end
      end
      
      if commit_message =~ @github_pat
        if @github_repo
          commit_message = commit_message.sub(@github_pat, '['+@link[:text_b]+'#\1'+@link[:text_a]+@link[:link_b]+@github_repo+'/issues/\1'+@link[:link_a]+']')
        else
          commit_message = commit_message.sub(@github_pat, '[#\1]')
        end
      end
      
      return commit_message
    end
    
    def get_log
      @jira_pat = /(\w{2,4}-\d+)/
      @github_pat = /\#(\d+)/
      if @until
        if @since
          gitlog = @git.log.between(@since.to_s, @until.to_s)
        else
          gitlog = @git.log.until(@until.to_s)
        end
        puts @h3 + " Version " + @until
      else
      gitlog = @git.log
      puts @h3 + " Release Notes"
      end
      
      @issues = []
      @entries = []

      gitlog.each do |commit|
        author_name = commit.author.name
        commit_message = commit.message
        commit_date = "[" + DateTime.parse(commit.date.to_s).strftime("%c") + "] "
        if !@date
          commit_date = ''
        end
        
        author_email = ''
        
        if @show_author
          author = author_name + author_email
          author = " __(" + author + ")__"
        else
          author = ' '
        end
        
        commit_message = highlight_commit_message(commit_message)

        sha = commit.sha
        longsha = sha
        sha = sha[0..6] if !@long_hash

        if @github_link_commit && @github_repo
          sha = "[" + @link[:text_b] + sha + @link[:text_a] + @link[:link_b] + @github_repo + "/commit/" + sha + @link[:link_a] + "]"
        else
          sha = "[" + sha + "]"
        end
        
        
        tagged = false
        if commit_message !~ /Merge/
          if commit_message.match(@jira_pat)
            tagged = commit_message.match(@jira_pat)[0]
          end
          @entries.push({:string => " * " + sha + " " + commit_message + author, :tagged => tagged})
        end
        
      end
      
      @issues.each do |i|
        puts "\n" + @h4 + " " + i.sub(@jira_pat, @link[:text_b]+'\1'+@link[:text_a]+@link[:link_b]+@jira_inst+'/browse/\1'+@link[:link_a])
        @entries.each do |e|
          puts e[:string] if e[:tagged] == i
        end
      end
      puts "\n" + @h4 + " Other Commits"
      @entries.each do |e|
        puts e[:string] if !e[:tagged]
      end
    end
    
  end
  
  class Config
    def self.parse
      thing = YAML.load_file(File.expand_path('config/releasenote.yml'))
      return thing
    end
  end
end

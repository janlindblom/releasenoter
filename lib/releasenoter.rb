require 'trollop'
require 'releasenoter/version'
require "git"

module Releasenoter
  patterns = {
    jira: /(\w{2,4}-\d+)/,
    github: /\#(\d+)/
  }
  class Cli
    def self.start_cli
      @opts = Trollop::options do
        version "Releasenoter " + Releasenoter::VERSION
        
        opt :since, "Starting point", :type => :string
        opt :to, "Ending at", :type => :string
        opt :github, "Highlight Github issue commits", :default => true
        opt :jira, "Highlight JIRA issue commits", :default => true
        opt :merges, "Include merge commits", :default => false
        opt :untagged, "Skip commits without issue references", :default => true
      end
    end
    
    def self.get_opts
      return @opts
    end
  end

  class FromGit
    def self.get_log
      cli_opts = Releasenoter::Cli.get_opts
      if cli_opts[:github]
        puts "Will highlight Github issue commits."
      end
      if cli_opts[:jira]
        puts "Will highlight JIRA issue commits."
      end
      if cli_opts[:merges]
        puts "Will include merge commits."
      end
      
      @git = Git.open('.')
      
      if cli_opts[:since] && !cli_opts[:to]
        gitlog = @git.log.since(cli_opts[:since])
      elsif cli_opts[:since] && cli_opts[:to]
        gitlog = @git.log.between(cli_opts[:since], cli_opts[:to])
      else
        gitlog = @git.log
      end
      
      gitlog.each do |commit|
        author_name = commit.author.name
        author_email = commit.author.email
        commit_message = commit.message
        sha = commit.sha
        if commit_message !~ /Merge/
          puts "(" + sha + ") " + author_name + " <" + author_email + ">: " + commit_message
        else
          if cli_opts[:merges]
            puts "(" + sha + ") " + author_name + " <" + author_email + ">: " + commit_message
          end
        end
      end
    end
  end
end

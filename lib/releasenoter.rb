require 'trollop'
require 'releasenoter/version'
require "git"
require "formatador"
require 'rake'
require 'rake/tasklib'
require 'yaml'

module Releasenoter
  class RakeTask < ::Rake::TaskLib
    include ::Rake::DSL if defined?(::Rake::DSL)
    
    attr_accessor :name
    attr_accessor :fail_on_error
    attr_accessor :verbose
    
    def initialize(*args, &task_block)
      setup_ivars(args)

      desc "Generate Release Notes" unless ::Rake.application.last_comment

      task :releasenote, :until, :since, :author, :author_email, :github_repo do |t, args|
        config = parse_config
        github_repo = config["github"] || get_remote
        author_email = config["author_email"] || false
        args.with_defaults(
          :until => 'Current',
          :since => nil,
          :author => true,
          :github_repo => github_repo,
          :github_link_commit => true,
          :jira_inst => config["jira"])
        puts "Args were: #{args}"
        get_tags
        #Releasenoter::Cli.start_cli
        get_log args
#        RakeFileUtils.send(:verbose, verbose) do
#          task_block.call(*[self, task_args].slice(0, task_block.arity)) if task_block
#          run_task verbose
#        end
      end
    end
    
    def setup_ivars(args)
      @root = Dir.pwd
      @name = File.basename(@root)
      @name = args.shift || :releasenote
      @verbose, @fail_on_error = true, true
    end
    
    def run_task(verbose)
      command = 'pwd'

      begin
        get_tags
        Releasenoter::Cli.start_cli
        Releasenoter::FromGit.get_log
        puts command if verbose
        success = system(command)
      rescue
        puts failure_message if failure_message
      end
      abort("#{command} failed") if fail_on_error unless success
    end
    
    private
    
    def parse_config
      thing = YAML.load_file('config/releasenote.yml')
      puts thing.inspect
      return thing
    end
    
    def get_tags
      @git = Git.open(@root)
    end
    
    def get_remote
      @git = Git.open('.')
      gh_repo_pat = /git@github\.com\:(\w.+\w)\.git/
      remote_origin = @git.config["remote.origin.url"]
      github_repo = nil
      
      if remote_origin =~ gh_repo_pat
        github_repo = 'https://github.com/' + remote_origin.sub(gh_repo_pat, '\1')
      end
      return github_repo
    end
    
    def get_log(args)
      f = Formatador.new
      jira_pat = /(\w{2,4}-\d+)/
      github_pat = /\#(\d+)/
      gh_repo_pat = /git@github\.com\:(\w.+\w)\.git/
      #cli_opts = Releasenoter::Cli.get_opts
      cli_opts = args

      if cli_opts[:until]
        gitlog = @git.log.until(cli_opts[:until].to_s)
        f.display_line "#### [" + cli_opts[:until] + "]"
      else
      gitlog = @git.log
      f.display_line "#### Release Notes"
      end

      gitlog.each do |commit|
        author_name = commit.author.name
        commit_message = commit.message
        commit_date = "[" + DateTime.parse(commit.date.to_s).strftime("%c") + "] "
        if !cli_opts[:date]
          commit_date = ''
        end
        
        author_email = ''
        
        if cli_opts[:author]
          author = ' ' + author_name + author_email
        else
          author = ' '
        end
        
        if commit_message =~ jira_pat
          if cli_opts[:jira_inst]
            commit_message = commit_message.sub(jira_pat, '[[blue]\1[/]]('+cli_opts[:jira_inst]+'/browse/\1)')
          else
            commit_message = commit_message.sub(jira_pat, '[[blue]\1[/]]')
          end
        end

        if commit_message =~ github_pat
          if cli_opts[:github_repo]
            commit_message = commit_message.sub(github_pat, '[[green]#\1[/]]('+cli_opts[:github_repo]+'/issues/\1)')
          else
            commit_message = commit_message.sub(github_pat, '[[green]#\1[/]]')
          end
        end

        sha = commit.sha
        longsha = sha
        sha = sha[0..6] if !cli_opts[:long]

        if cli_opts[:github_link_commit] && cli_opts[:github_repo]
          sha = "[" + sha + "](" + cli_opts[:github_repo] + "/commit/" + sha + ")"
        else
          sha = "[" + sha + "]"
        end
        
        author = " __(" + author + ")__"

        if commit_message !~ /Merge/
          f.display_line " * " + sha + " " + commit_message + author
        else
          if cli_opts[:merges]
            f.display_line " * " + sha + " " + commit_message + author
          end
        end
      end
    end
    
  end
  
  class Cli
    @opts = []
    def self.start_cli
      @opts = Trollop::options do
        version "Releasenoter " + Releasenoter::VERSION

        opt :long, "Use long SHA hashes", :default => false
        opt :date, "Show date", :default => true
        opt :author, "Show author", :default => true
        opt :since, "Starting point (committish, date, tag...)", :type => :string
        opt :until, "Ending point (committish, date, tag...)", :type => :string
        opt :merges, "Include merge commits", :default => false
        opt :tagged, "Only include commits without issue references", :default => false
        opt :author_email, "Show author email", :default => true
        opt :no_github_highlight, "Don't highlight Github issue commits", :default => false
        opt :github_user, "Github username", :type => :string
        opt :github_repo, "URL to Github", :type => :string
        opt :github_link, "Link the hash to the commit on Github", :default => true
        opt :jira_inst, "URL to the JIRA instance", :type => :string
        opt :no_jira_highlight, "Don't highlight JIRA issue commits", :default => false
      end
    end

    def self.get_opts
      return @opts
    end
    
  end

  class FromGit
    
  end
end

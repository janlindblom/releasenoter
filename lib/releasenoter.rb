require 'trollop'
require 'releasenoter/version'
require "git"
require "formatador"

#require 'jiraSOAP'
#require 'github_api'

module Releasenoter
  class Cli
    @opts = []
    def self.start_cli
      @opts = Trollop::options do
        version "Releasenoter " + Releasenoter::VERSION

        opt :long, "Use long SHA hashes", :default => false
        opt :since, "Starting point (committish, date, tag...)", :type => :string
        opt :until, "Ending point (committish, date, tag...)", :type => :string
        opt :merges, "Include merge commits", :default => false
        opt :tagged, "Only include commits without issue references", :default => false
        opt :author_email, "Show author email", :default => true
        opt :no_github_highlight, "Don't highlight Github issue commits", :default => false
        opt :github_user, "Github username", :type => :string
        opt :github_repo, "URL to the Github repository", :type => :string
        opt :jira_inst, "URL to the JIRA instance", :type => :string
        opt :no_jira_highlight, "Don't highlight JIRA issue commits", :default => false
      end
    end

    def self.get_opts
      return @opts
    end
  end

  class FromGit
    def self.get_log
      f = Formatador.new
      jira_pat = /(\w{2,4}-\d+)/
      github_pat = /\#(\d+)/
      cli_opts = Releasenoter::Cli.get_opts

      if !cli_opts[:no_github_highlight]
        if cli_opts[:github_repo]
          f.display_line "Will highlight Github issue commits (like so: ([green]#1[/])[" + cli_opts[:github_repo] + "])."
        else
          f.display_line "Will highlight Github issue commits (like so: [[green]#1[/]])."
        end
      end
      if !cli_opts[:no_jira_highlight]
        if cli_opts[:jira_inst]
          f.display_line "Will highlight JIRA issue commits (like so: ([blue]ABCD-1[/]])[" + cli_opts[:jira_inst] + "]."
        else
          f.display_line "Will highlight JIRA issue commits (like so: [[blue]ABCD-1[/]])."
        end
      end
      if cli_opts[:merges]
        f.display_line "Will include merge commits."
      end

      @git = Git.open('.')

      if cli_opts[:since]
        if !cli_opts[:until]
          gitlog = @git.log.since(cli_opts[:since].to_s)
        elsif cli_opts[:until]
          gitlog = @git.log.between(cli_opts[:since].to_s, cli_opts[:until].to_s)
        end
      elsif cli_opts[:until]
        if !cli_opts[:since]
          gitlog = @git.log.until(cli_opts[:until].to_s)
        end
      else
      gitlog = @git.log
      end

      gitlog.each do |commit|
        author_name = commit.author.name
        author_email = " <" + commit.author.email + ">"
        if cli_opts[:author_email]
          author_email = ''
        end
        commit_message = commit.message
        commit_date = commit.date
        if commit_message =~ jira_pat
          commit_message = commit_message.sub(jira_pat, '[[blue]\1[/]]')
        end

        if commit_message =~ github_pat
          commit_message = commit_message.sub(github_pat, '[[green]#\1[/]]')
        end

        sha = commit.sha
        if !cli_opts[:long]
        sha = sha[0..6]
        end
        if commit_message !~ /Merge/
          f.display_line "* [" + commit_date.to_s + "] (" + sha + ") " + author_name + author_email + ": " + commit_message
        else
          if cli_opts[:merges]
            f.display_line "* [" + commit_date.to_s + "] (" + sha + ") " + author_name + " <" + author_email + ">: " + commit_message
          end
        end
      end
    end
  end
end

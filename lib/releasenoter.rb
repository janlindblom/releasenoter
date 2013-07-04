require 'trollop'
require 'releasenoter/version'
require "git"
require "formatador"

module Releasenoter
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
    def self.get_log
      f = Formatador.new
      jira_pat = /(\w{2,4}-\d+)/
      github_pat = /\#(\d+)/
      gh_repo_pat = /git@github\.com\:(\w.+\w)\.git/
      cli_opts = Releasenoter::Cli.get_opts

      @git = Git.open('.')
      
      remote_origin = @git.config["remote.origin.url"]
      
      if remote_origin =~ gh_repo_pat
        cli_opts[:github_repo] = 'https://github.com/' + remote_origin.sub(gh_repo_pat, '\1')
      end

      if cli_opts[:since]
        if !cli_opts[:until]
          gitlog = @git.log.since(cli_opts[:since].to_s)
          f.display_line "# Release Notes since " + cli_opts[:since]
        elsif cli_opts[:until]
          gitlog = @git.log.between(cli_opts[:since].to_s, cli_opts[:until].to_s)
          f.display_line "# Release Notes between " + cli_opts[:since] + " and " + cli_opts[:until]
        end
      elsif cli_opts[:until]
        if !cli_opts[:since]
          gitlog = @git.log.until(cli_opts[:until].to_s)
          f.display_line "# Release Notes until " + cli_opts[:until]
        end
      else
      gitlog = @git.log
      f.display_line "# Release Notes"
      end

      gitlog.each do |commit|
        author_name = commit.author.name
        author_email = " <" + commit.author.email + ">"
        commit_message = commit.message
        commit_date = "[" + DateTime.parse(commit.date.to_s).strftime("%c") + "] "
        if !cli_opts[:date]
          commit_date = ''
        end
        
        if cli_opts[:author_email]
          author_email = ''
        end
        
        if cli_opts[:author]
          author = ' ' + author_name + author_email
        else
          author = ''
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

        sha = "[" + sha + "](" + cli_opts[:github_repo] + "/commit/" + longsha + ")" if cli_opts[:github_link_commit] && cli_opts[:github_repo]

        if commit_message !~ /Merge/
          f.display_line " * " + commit_date.to_s + "(" + sha + ")" + author + ": " + commit_message
        else
          if cli_opts[:merges]
            f.display_line " * " + commit_date.to_s + "(" + sha + ")" + author + ": " + commit_message
          end
        end
      end
    end
  end
end

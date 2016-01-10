module Lita
  module Handlers
    class CapistranoRails < Handler
      # example:
      # config.handlers.capistrano_rails.apps = {
      #   'app1' => {
      #     git: 'git@git.example.com:account/app1.git',
      #   }, # this will use "production" as rails env and using "master" branch
      #   'app2' => {
      #     git: 'git@git.example.com:account/app2.git',
      #       envs: {
      #         'production' => 'master',
      #         'staging' => 'develop',
      #       }
      #   },
      # }
      config :apps, type: Hash, required: true

      on :loaded, :define_routes

      def define_routes(payload)
        define_static_routes
        define_dinamic_routes
      end

      def deploy_list_apps(response)
        response.reply_privately('Available apps:')
        apps = config.apps.map do |app, app_config|
          envs = app_config[:envs] ? app_config[:envs].keys.join(",") : 'production'
          "#{app}(#{envs})"
        end
        response.reply_privately(apps )
      end

      # command: "deploy #{env} for #{app}"
      def deploy_env_for_app(response)
        env = response.matches[0][0]
        app = response.matches[0][1]
        deploy_app(app, env, response)
      end

      # command: "deploy #{app}"
      def deploy_production_for_app(response)
        env = 'production'
        app = response.matches[0][0]
        deploy_app(app, env, response)
      end

      def deploy_app(app, env, response)
        app_config = config.apps[app]

        # check env
        app_envs = app_config[:envs] ? app_config[:envs].keys : ['production'] # use "production" as default env
        if !app_envs.include?(env)
          return response.reply(%{"#{env}" is not available env for #{app}, available env is: #{app_envs.join("|")}})
        end

        branch = app_config[:envs] ? app_config[:envs][env] : 'master' # use "master" as default branch

        response.reply("I'm deploying #{env} using #{branch} branch for #{app} ...")

        # prepare the dirs
        app_path    = File.expand_path("tmp/capistrano_rails/apps/#{app}")
        app_source_path = File.expand_path("#{app_path}/source")
        bundle_path     = File.expand_path("tmp/capistrano_rails/bundle") # sharing bundle to reduce space usage and reuse gems
        FileUtils.mkdir_p(app_path)

        # get source code
        log.info 'get source code'
        # if dir ".git" exists, use `git pull`
        if File.exists?("#{app_source_path}/.git")
          log.info 'Found ".git" exists, run `git pull`'
          # run_in_dir("git checkout #{branch} && git pull", app_source_path)
          revision = "origin/#{branch}"
          # since we're in a local branch already, just reset to specified revision rather than merge
          run_in_dir("git fetch #{verbose} && git reset #{verbose} --hard #{revision}", app_source_path)
        else
          log.info 'not found ".git", run `git clone`'
          run_in_dir("git clone -b #{branch} #{app_config[:git]} source", app_path)
        end

        # if ".git" exists but repo url changed, clean up the dir then run `git clone`

        log.info 'run `bundle install`'
        # run_in_dir("bundle install --quiet", app_source_path)
        run_in_dir("bundle install --gemfile #{app_source_path}/Gemfile --path #{bundle_path} --deployment --without darwin test", app_source_path)
        # TODO: check result, reply failure message
        # TODO: check result, auto rety 1 time if timeout as "Gem::RemoteFetcher::FetchError: Errno::ETIMEDOUT: Operation timed out"


        # TODO: check "Capfile"
        # if "Capfile" not exits, reply "not a capistrano project"
        log.info "run \`cap #{env} deploy\`"
        run_in_dir("bundle exec cap #{env} deploy", app_source_path)
        # TODO: check result, reply failure message

        deploy_success = "deploy #{env} for #{app} finished!"

        # TODO: get "app_url"
        app_url = ""
        deploy_success += ", please visit #{app_url}" if !app_url.empty?

        response.reply(deploy_success)
      end

      private
      def run_in_dir(cmd, dir)
        lita_mark = "LITA=#{Lita::VERSION}"
        _cmd = "cd #{dir} && #{lita_mark} #{cmd}"
        log.info _cmd
        # running bundle install inside a bundle-managed shell to avoid "RuntimeError: Specs already loaded"
        # see https://github.com/bundler/bundler/issues/1981#issuecomment-6292686
        Bundler.with_clean_env do
          system(_cmd)
        end
      end

      def verbose
        # config.scm_verbose ? nil : "-q"
      end

      def define_static_routes
        self.class.route(
          %r{deploy\s+list},
          :deploy_list_apps,
          command: true,
          help: { "deploy list" => "List available apps for deploy"}
        )
      end

      # define route for each rapporteur
      def define_dinamic_routes
        config.apps.each do |app, app_config|
          # define command "deploy APP"
          self.class.route(
            %r{deploy (#{app})$},
            :deploy_production_for_app,
            command: true,
            # restrict_to: [:admins, value[:deploy_group]],
            help: { "deploy #{app}" => "deploy produciton for #{app}"}
          )

          # define command "deploy ENV for APP"
          # puts "define route: ^deploy\s+(#{app})\s+(#{area})\s+(.+)\s+(.+)"
          envs = app_config[:envs] ? app_config[:envs].keys : ['production']
          self.class.route(
            %r{deploy +(\w+) +for +(#{app})$},
            :deploy_env_for_app,
            command: true,
            # restrict_to: [:admins, value[:deploy_group]],
            help: { "deploy #{envs.join("|")} for #{app}" => "deploy ENV for #{app}"}
          )
        end
      end

      Lita.register_handler(self)
    end
  end
end

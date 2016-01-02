module Lita
  module Handlers
    class CapistranoRails < Handler
      # example:
      # config.handlers.capistrano_rails.apps = {
      #   'app1' => {
      #     git: 'git@git.example.com:account/app1.git',
      #     envs: ['production', 'staging'],
      #   },
      #   'app2' => {
      #     git: 'git@git.example.com:account/app2.git',
      #     envs: ['staging'],
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
          "#{app}(#{app_config[:envs].join(",")})"
        end
        response.reply_privately(apps )
      end

      # "deploy #{env} for #{app}"
      def deploy_app(response)
        env = response.matches[0][0]
        app = response.matches[0][1]

        # check env
        if !config.apps[app][:envs].include?(env)
          return response.reply(%{env "#{env}" is not available for #{app}})
        end

        response.reply("deply #{env} for #{app}")
      end

      private

      def define_static_routes
        self.class.route(
          %r{^deploy\s+list},
          :deploy_list_apps,
          command: true,
          help: { "deploy list" => "List available apps for deploy"}
        )
      end

      # define route for each rapporteur
      def define_dinamic_routes
        config.apps.each do |app, app_config|
          # puts "define route: ^deploy\s+(#{app})\s+(#{area})\s+(.+)\s+(.+)"
          self.class.route(
            %r{^deploy +(\w+) +for +(#{app})$},
            :deploy_app,
            command: true,
            # restrict_to: [:admins, value[:deploy_group]],
            help: { "deploy #{app_config[:envs].join("|")} for #{app}" => "deploy ENV for #{app}"}
          )
        end
      end

      Lita.register_handler(self)
    end
  end
end

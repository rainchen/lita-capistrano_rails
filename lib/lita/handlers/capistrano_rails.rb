module Lita
  module Handlers
    class CapistranoRails < Handler
      # example:
      # config.handlers.capistrano_rails.apps = {
      #   'app1' => {
      #     git: 'git@git.example.com:account/app1.git',
      #     rails_env: 'production',
      #   },
      #   'app2' => {
      #     git: 'git@git.example.com:account/app2.git',
      #     rails_env: 'staging',
      #   },
      # }
      config :apps, type: Hash, required: true

      on :loaded, :define_routes

      def define_routes(payload)
        define_static_routes
      end

      def deploy_list_apps(response)
        response.reply_privately('Available apps:')
        apps = config.apps.map do |app, app_config|
          "#{app}[#{app_config[:rails_env]}]"
        end
        response.reply_privately(apps )
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

      Lita.register_handler(self)
    end
  end
end

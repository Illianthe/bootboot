# frozen_string_literal: true

module Bootboot
  class GemfileNextAutoSync < Bundler::Plugin::API
    def setup
      return if ENV['SKIP_BUNDLER_AUTOSYNC']
      check_bundler_version
      opt_in
    end

    private

    def check_bundler_version
      self.class.hook("before-install-all") do
        next if Bundler::VERSION >= "1.17.0" || !GEMFILE_NEXT_LOCK.exist?

        Bundler.ui.warn(<<-EOM.gsub(/\s+/, " "))
          Bootboot can't automatically sync your Gemfiles because you are running
          an older version of Bundler.

          Update Bundler to 1.17.0 to discard this warning.
        EOM
      end
    end

    def opt_in
      self.class.hook('before-install-all') do
        @previous_lock = Bundler.default_lockfile.read
      end

      self.class.hook("after-install-all") do
        current_definition = Bundler.definition
        next unless GEMFILE_NEXT_LOCK.exist?
        update!(current_definition)
      end
    end

    def update!(current_definition)
      last_env_previous = ENV.delete(Bootboot.env_previous)
      last_env_next = ENV.delete(Bootboot.env_next)

      env = which_env
      lock = which_lock

      Bundler.ui.confirm("Updating the #{lock}")
      ENV[env] = '1'
      ENV['SKIP_BUNDLER_PATCH'] = '1'

      unlock = current_definition.instance_variable_get(:@unlock)
      definition = Bundler::Definition.build(GEMFILE, lock, unlock)
      definition.resolve_remotely!
      definition.lock(lock)
    ensure
      ENV.delete(env)
      ENV.delete('SKIP_BUNDLER_PATCH')
      ENV[Bootboot.env_previous] = last_env_previous unless last_env_previous.nil?
      ENV[Bootboot.env_next] = last_env_next unless last_env_next.nil?
    end

    def which_env
      if Bundler.default_lockfile.to_s =~ /_next\.lock/
        Bootboot.env_previous
      else
        Bootboot.env_next
      end
    end

    def which_lock
      if Bundler.default_lockfile.to_s =~ /_next\.lock/
        GEMFILE_LOCK
      else
        GEMFILE_NEXT_LOCK
      end
    end
  end
end

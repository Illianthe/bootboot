# frozen_string_literal: true

module Bootboot
  class GemfileNextAutoSync < Bundler::Plugin::API
    def setup
      check_bundler_version
      opt_in
    end

    private

    def check_bundler_version
      self.class.hook("before-install-all") do
        next if Bundler::VERSION >= "1.17.0" || !GEMFILE_NEXT_LOCK.exist?

        Bundler.ui.warn(<<-EOM.gsub(/\s+/, " "))
          Bootboot can't automatically update the Gemfile_next.lock because you are running
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

        Bundler.ui.confirm("Test")

        next if !GEMFILE_NEXT_LOCK.exist? ||
                nothing_changed?(current_definition) ||
                ENV[Bootboot.env_next] ||
                ENV[Bootboot.env_previous]

        update!(current_definition)
      end
    end

    def nothing_changed?(current_definition)
      current_definition.to_lock == @previous_lock
    end

    def update!(current_definition)
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
